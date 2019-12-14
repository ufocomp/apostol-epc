/*++

Program name:

  Apostol WebService

Module Name:

  WebService.cpp

Notices:

  Module WebService

Author:

  Copyright (c) Prepodobny Alen

  mailto: alienufo@inbox.ru
  mailto: ufocomp@gmail.com

--*/

//----------------------------------------------------------------------------------------------------------------------

#include "Core.hpp"
#include "WebService.hpp"
//----------------------------------------------------------------------------------------------------------------------

#include <openssl/sha.h>
#include "rapidxml.hpp"
//----------------------------------------------------------------------------------------------------------------------

extern "C++" {

namespace Apostol {

    namespace WebService {

        CString to_string(unsigned long Value) {
            TCHAR szString[_INT_T_LEN + 1] = {0};
            sprintf(szString, "%lu", Value);
            return CString(szString);
        }

        //--------------------------------------------------------------------------------------------------------------

        //-- CWebService -----------------------------------------------------------------------------------------------

        //--------------------------------------------------------------------------------------------------------------

        CWebService::CWebService(CModuleManager *AManager) : CApostolModule(AManager) {
            m_Version = -1;
            m_Jobs = new CJobManager();
            m_Headers.Add("Authorization");
            InitMethods();
        }
        //--------------------------------------------------------------------------------------------------------------

        CWebService::~CWebService() {
            delete m_Jobs;
        }
        //--------------------------------------------------------------------------------------------------------------

        void CWebService::InitMethods() {
            m_Methods.AddObject(_T("GET"), (CObject *) new CMethodHandler(true, std::bind(&CWebService::DoGet, this, _1)));
            m_Methods.AddObject(_T("POST"), (CObject *) new CMethodHandler(true, std::bind(&CWebService::DoPost, this, _1)));
            m_Methods.AddObject(_T("OPTIONS"), (CObject *) new CMethodHandler(true, std::bind(&CWebService::DoOptions, this, _1)));
            m_Methods.AddObject(_T("PUT"), (CObject *) new CMethodHandler(false, std::bind(&CWebService::MethodNotAllowed, this, _1)));
            m_Methods.AddObject(_T("DELETE"), (CObject *) new CMethodHandler(false, std::bind(&CWebService::MethodNotAllowed, this, _1)));
            m_Methods.AddObject(_T("TRACE"), (CObject *) new CMethodHandler(false, std::bind(&CWebService::MethodNotAllowed, this, _1)));
            m_Methods.AddObject(_T("HEAD"), (CObject *) new CMethodHandler(false, std::bind(&CWebService::MethodNotAllowed, this, _1)));
            m_Methods.AddObject(_T("PATCH"), (CObject *) new CMethodHandler(false, std::bind(&CWebService::MethodNotAllowed, this, _1)));
            m_Methods.AddObject(_T("CONNECT"), (CObject *) new CMethodHandler(false, std::bind(&CWebService::MethodNotAllowed, this, _1)));
        }
        //--------------------------------------------------------------------------------------------------------------

        void CWebService::DebugRequest(CRequest *ARequest) {
            DebugMessage("[%p] Request:\n%s %s HTTP/%d.%d\n", ARequest, ARequest->Method.c_str(), ARequest->Uri.c_str(), ARequest->VMajor, ARequest->VMinor);

            for (int i = 0; i < ARequest->Headers.Count(); i++)
                DebugMessage("%s: %s\n", ARequest->Headers[i].Name.c_str(), ARequest->Headers[i].Value.c_str());

            if (!ARequest->Content.IsEmpty())
                DebugMessage("\n%s\n", ARequest->Content.c_str());
        }
        //--------------------------------------------------------------------------------------------------------------

        void CWebService::DebugReply(CReply *AReply) {
            DebugMessage("[%p] Reply:\nHTTP/%d.%d %d %s\n", AReply, AReply->VMajor, AReply->VMinor, AReply->Status, AReply->StatusText.c_str());

            for (int i = 0; i < AReply->Headers.Count(); i++)
                DebugMessage("%s: %s\n", AReply->Headers[i].Name.c_str(), AReply->Headers[i].Value.c_str());

            if (!AReply->Content.IsEmpty())
                DebugMessage("\n%s\n", AReply->Content.c_str());
        }
        //--------------------------------------------------------------------------------------------------------------

        void CWebService::DebugConnection(CHTTPServerConnection *AConnection) {
            DebugMessage("\n[%p] [%s:%d] [%d] ", AConnection, AConnection->Socket()->Binding()->PeerIP(),
                         AConnection->Socket()->Binding()->PeerPort(), AConnection->Socket()->Binding()->Handle());

            DebugRequest(AConnection->Request());

            static auto OnReply = [](CObject *Sender) {
                auto LConnection = dynamic_cast<CHTTPServerConnection *> (Sender);

                DebugMessage("\n[%p] [%s:%d] [%d] ", LConnection, LConnection->Socket()->Binding()->PeerIP(),
                             LConnection->Socket()->Binding()->PeerPort(), LConnection->Socket()->Binding()->Handle());

                DebugReply(LConnection->Reply());
            };

            AConnection->OnReply(OnReply);
        }
        //--------------------------------------------------------------------------------------------------------------

        void CWebService::ExceptionToJson(int ErrorCode, const std::exception &AException, CString& Json) {
            TCHAR ch;
            LPCTSTR lpMessage = AException.what();
            CString Message;

            while ((ch = *lpMessage++) != 0) {
                if ((ch == '"') || (ch == '\\'))
                    Message.Append('\\');
                Message.Append(ch);
            }

            Json.Format(R"({"error": {"code": %u, "message": "%s"}})", ErrorCode, Message.c_str());
        }
        //--------------------------------------------------------------------------------------------------------------

        void CWebService::DoPostgresQueryException(CPQPollQuery *APollQuery, Delphi::Exception::Exception *AException) {
            auto LConnection = dynamic_cast<CHTTPServerConnection *> (APollQuery->PollConnection());

            if (LConnection != nullptr) {
                auto LReply = LConnection->Reply();

                CReply::status_type LStatus = CReply::internal_server_error;

                ExceptionToJson(0, *AException, LReply->Content);

                LConnection->SendReply(LStatus);
            }

            Log()->Error(APP_LOG_EMERG, 0, AException->what());
        }
        //--------------------------------------------------------------------------------------------------------------

        void CWebService::PQResultToJson(CPQResult *Result, CString &Json) {
            Json = "{";

            for (int I = 0; I < Result->nFields(); ++I) {
                if (I > 0) {
                    Json += ", ";
                }

                Json += "\"";
                Json += Result->fName(I);
                Json += "\"";

                if (SameText(Result->fName(I),_T("session"))) {
                    Json += ": ";
                    if (Result->GetIsNull(0, I)) {
                        Json += _T("null");
                    } else {
                        Json += "\"";
                        Json += Result->GetValue(0, I);
                        Json += "\"";
                    }
                } else if (SameText(Result->fName(I),_T("result"))) {
                    Json += ": ";
                    if (SameText(Result->GetValue(0, I), _T("t"))) {
                        Json += _T("true");
                    } else {
                        Json += _T("false");
                    }
                } else {
                    Json += ": \"";
                    Json += Result->GetValue(0, I);
                    Json += "\"";
                }
            }

            Json += "}";
        }
        //--------------------------------------------------------------------------------------------------------------

        void CWebService::QueryToJson(CPQPollQuery *Query, CString& Json) {

            CPQResult *Run;
            CPQResult *Login;
            CPQResult *Result;

            for (int I = 0; I < Query->Count(); I++) {
                Result = Query->Results(I);
                if (Result->ExecStatus() != PGRES_TUPLES_OK)
                    throw Delphi::Exception::EDBError(Result->GetErrorMessage());
            }

            if (Query->Count() == 3) {
                Login = Query->Results(0);

                if (SameText(Login->GetValue(0, 1), "f")) {
                    Log()->Error(APP_LOG_EMERG, 0, Login->GetValue(0, 2));
                    PQResultToJson(Login, Json);
                    return;
                }

                Run = Query->Results(1);
            } else {
                Run = Query->Results(0);
            }

            Json = "{\"result\": ";

            if (Run->nTuples() > 0) {

                Json += "[";
                for (int Row = 0; Row < Run->nTuples(); ++Row) {
                    for (int Col = 0; Col < Run->nFields(); ++Col) {
                        if (Row != 0)
                            Json += ", ";
                        if (Run->GetIsNull(Row, Col)) {
                            Json += "null";
                        } else {
                            Json += Run->GetValue(Row, Col);
                        }
                    }
                }
                Json += "]";

            } else {
                Json += "{}";
            }

            Json += "}";
        }
        //--------------------------------------------------------------------------------------------------------------

        void CWebService::DoPostgresQueryExecuted(CPQPollQuery *APollQuery) {
            clock_t start = clock();

            auto LConnection = dynamic_cast<CHTTPServerConnection *> (APollQuery->PollConnection());

            if (LConnection != nullptr) {

                auto LReply = LConnection->Reply();

                CReply::status_type LStatus = CReply::internal_server_error;

                try {
                    QueryToJson(APollQuery, LReply->Content);
                    LStatus = CReply::ok;
                } catch (Delphi::Exception::Exception &E) {
                    ExceptionToJson(0, E, LReply->Content);
                    Log()->Error(APP_LOG_EMERG, 0, E.what());
                }

                LConnection->SendReply(LStatus, nullptr, true);

            } else {

                auto LJob = m_Jobs->FindJobByQuery(APollQuery);

                if (LJob != nullptr) {
                    try {
                        QueryToJson(APollQuery, LJob->Result());
                    } catch (Delphi::Exception::Exception &E) {
                        ExceptionToJson(0, E, LJob->Result());
                        Log()->Error(APP_LOG_EMERG, 0, E.what());
                    }
                }
            }

            log_debug1(APP_LOG_DEBUG_CORE, Log(), 0, _T("Query executed runtime: %.2f ms."), (double) ((clock() - start) / (double) CLOCKS_PER_SEC * 1000));
        }
        //--------------------------------------------------------------------------------------------------------------

        bool CWebService::QueryStart(CHTTPServerConnection *AConnection, const CStringList& SQL) {
            auto LQuery = GetQuery(AConnection);

            if (LQuery == nullptr)
                throw Delphi::Exception::Exception("QueryStart: GetQuery() failed!");

            LQuery->SQL() = SQL;

            if (LQuery->QueryStart() != POLL_QUERY_START_ERROR) {
                if (m_Version == 2) {
                    auto LJob = m_Jobs->Add(LQuery);
                    auto LReply = AConnection->Reply();

                    LReply->Content = "{\"jobid\":" "\"" + LJob->JobId() + "\"}";

                    AConnection->SendReply(CReply::accepted);
                } else {
                    // Wait query result...
                    AConnection->CloseConnection(false);
                }

                return true;
            } else {
                delete LQuery;
            }

            return false;
        }
        //--------------------------------------------------------------------------------------------------------------

        bool CWebService::APIRun(CHTTPServerConnection *AConnection, const CString &Route, const CString &jsonString,
                const CAuthorization &Authorization) {

            CStringList SQL;

            SQL.Add(CString());

            if (Route == "/login") {
                SQL.Last().Format("SELECT * FROM api.run('%s', '%s'::jsonb);",
                                            Route.c_str(), jsonString.IsEmpty() ? "{}" : jsonString.c_str());
            } else {
                if (Authorization.Session.IsEmpty()) {
                    SQL.Last().Format("SELECT * FROM api.login('%s', '%s');",
                                      Authorization.Username.c_str(), Authorization.Password.c_str());

                    SQL.Add(CString());
                    SQL.Last().Format("SELECT * FROM api.run('%s', '%s'::jsonb);",
                                      Route.c_str(), jsonString.IsEmpty() ? "{}" : jsonString.c_str());

                    SQL.Add("SELECT * FROM api.logout();");
                } else {
                    SQL.Last().Format("SELECT * FROM api.run('%s', '%s'::jsonb, '%s');",
                                      Route.c_str(), jsonString.IsEmpty() ? "{}" : jsonString.c_str(),
                                      Authorization.Session.c_str());
                }
            }

            return QueryStart(AConnection, SQL);
        }
        //--------------------------------------------------------------------------------------------------------------

        void CWebService::DoWWW(CHTTPServerConnection *AConnection) {
            auto LServer = dynamic_cast<CHTTPServer *> (AConnection->Server());
            auto LRequest = AConnection->Request();
            auto LReply = AConnection->Reply();

            TCHAR szExt[PATH_MAX] = {0};

            LReply->ContentType = CReply::html;

            // Decode url to path.
            CString LRequestPath;
            if (!LServer->URLDecode(LRequest->Uri, LRequestPath)) {
                AConnection->SendStockReply(CReply::bad_request);
                return;
            }

            // Request path must be absolute and not contain "..".
            if (LRequestPath.empty() || LRequestPath.front() != '/' || LRequestPath.find("..") != CString::npos) {
                AConnection->SendStockReply(CReply::bad_request);
                return;
            }

            // If path ends in slash (i.e. is a directory) then add "index.html".
            if (LRequestPath.back() == '/') {
                LRequestPath += "index.html";
            }

            // Open the file to send back.
            const CString LFullPath = LServer->DocRoot() + LRequestPath;
            if (!FileExists(LFullPath.c_str())) {
                AConnection->SendStockReply(CReply::not_found);
                return;
            }

            LReply->Content.LoadFromFile(LFullPath.c_str());

            // Fill out the CReply to be sent to the client.
            AConnection->SendReply(CReply::ok, Mapping::ExtToType(ExtractFileExt(szExt, LRequestPath.c_str())));
        }
        //--------------------------------------------------------------------------------------------------------------

        void CWebService::DoGet(CHTTPServerConnection *AConnection) {
            auto LRequest = AConnection->Request();
            auto LReply = AConnection->Reply();

            CStringList LUri;
            SplitColumns(LRequest->Uri.c_str(), LRequest->Uri.Size(), &LUri, '/');

            if (LUri.Count() < 3) {
                DoWWW(AConnection);
                return;
            }

            const auto& LService = LUri[0];
            const auto& LVersion = LUri[1];
            const auto& LCommand = LUri[2];

            if (LVersion == "v1") {
                m_Version = 1;
            } else if (LVersion == "v2") {
                m_Version = 2;
            }

            if (LService != "api" || (m_Version == -1)) {
                DoWWW(AConnection);
                return;
            }

            try {
                if (LCommand == "ping") {

                    AConnection->SendStockReply(CReply::ok);

                } else if (LCommand == "time") {

                    LReply->Content << "{\"serverTime\": " << to_string(MsEpoch()) << "}";

                    AConnection->SendReply(CReply::ok);

                } else {

                    const auto& LAction = LUri.Count() == 4 ? LUri[3] : "";

                    const CString &LAuthorization = LRequest->Headers.Values(_T("authorization"));

                    if (LAuthorization.IsEmpty()) {
                        AConnection->SendStockReply(CReply::unauthorized);
                        return;
                    }

                    CAuthorization Authorization(LAuthorization);

                    if (Authorization.Schema == asSession) {
                        LReply->AddHeader(_T("Authorization"), _T("Session "));
                        LReply->Headers.Last().Value += Authorization.Session;
                    }

                    auto CheckParam = [LRequest, &LAction] (CString& Route, CJSON& Content) {

                        const CString &Id = LRequest->Params["id"];
                        if (!Id.IsEmpty())
                            Content.Object().AddPair("id", Id);

                        if (LAction == "Method") {
                            Route << "/method";
                        } else if (LAction == "Count") {
                            Route << "/count";
                        } else {
                            if (Id.IsEmpty()) {
                                Route << "/lst";
                            } else {
                                Route << "/get";
                            }
                        }
                    };

                    CJSON Content;
                    CString Route;

                    if (LCommand == "Method") {

                        const CString& Object = LRequest->Params["object"];
                        const CString& Class = LRequest->Params["class"];
                        const CString& State = LRequest->Params["state"];
                        const CString& ClassCode = LRequest->Params["classcode"];
                        const CString& StateCode = LRequest->Params["statecode"];

                        Route = "/method/get";

                        if (!Object.IsEmpty())
                            Content.Object().AddPair("object", Object);

                        if (!State.IsEmpty())
                            Content.Object().AddPair("state", State);

                        if (!Class.IsEmpty())
                            Content.Object().AddPair("class", Class);

                        if (!ClassCode.IsEmpty())
                            Content.Object().AddPair("classcode", ClassCode);

                        if (!StateCode.IsEmpty())
                            Content.Object().AddPair("statecode", StateCode);

                    } else if (LCommand == "Client") {
                        Route = "/client";
                        CheckParam(Route, Content);
                    } else if (LCommand == "ChargePoint") {
                        Route = "/charge_point";
                        CheckParam(Route, Content);
                    } else if (LCommand == "Card") {
                        Route = "/card";
                        CheckParam(Route, Content);
                    }

                    if (!Route.IsEmpty()) {
                        if (!APIRun(AConnection, Route, Content.ToString(), Authorization)) {
                            AConnection->SendStockReply(CReply::internal_server_error);
                        }
                    } else {
                        AConnection->SendStockReply(CReply::not_found);
                    }
                }
            } catch (std::exception &e) {
                ExceptionToJson(0, e, LReply->Content);

                AConnection->CloseConnection(true);
                AConnection->SendReply(CReply::bad_request);

                Log()->Error(APP_LOG_EMERG, 0, e.what());
            }
        }
        //--------------------------------------------------------------------------------------------------------------

        void CWebService::DoPost(CHTTPServerConnection *AConnection) {
            auto LRequest = AConnection->Request();
            auto LReply = AConnection->Reply();

            CStringList LUri;
            SplitColumns(LRequest->Uri.c_str(), LRequest->Uri.Size(), &LUri, '/');
            if (LUri.Count() < 2) {
                AConnection->SendStockReply(CReply::not_found);
                return;
            }

            if (LUri[1] == _T("v1")) {
                m_Version = 1;
            } else if (LUri[1] == _T("v2")) {
                m_Version = 2;
            }

            if (LUri[0] != _T("api") || (m_Version == -1)) {
                AConnection->SendStockReply(CReply::not_found);
                return;
            }

            const CString &LContentType = LRequest->Headers.Values(_T("content-type"));
            if (!LContentType.IsEmpty() && LRequest->ContentLength == 0) {
                AConnection->SendStockReply(CReply::no_content);
                return;
            }

            CString LRoute;
            for (int I = 2; I < LUri.Count(); ++I) {
                LRoute.Append('/');
                LRoute.Append(LUri[I].Lower());
            }

            const CString &LAuthorization = LRequest->Headers.Values(_T("authorization"));

            if (LAuthorization.IsEmpty()) {

                if (LRoute == "/login") {
                    if (!APIRun(AConnection, LRoute, LRequest->Content, CAuthorization())) {
                        AConnection->SendStockReply(CReply::internal_server_error);
                    }
                } else {
                    AConnection->SendStockReply(CReply::unauthorized);
                }

                return;
            }

            try {
                CAuthorization Authorization(LAuthorization);

                if (Authorization.Schema == asSession) {
                    LReply->AddHeader(_T("Authorization"), _T("Session "));
                    LReply->Headers.Last().Value += Authorization.Session;
                }

                if (!APIRun(AConnection, LRoute, LRequest->Content, Authorization)) {
                    AConnection->SendStockReply(CReply::internal_server_error);
                }
            } catch (Delphi::Exception::Exception &E) {
                ExceptionToJson(0, E, LReply->Content);
                AConnection->CloseConnection(true);
                AConnection->SendReply(CReply::bad_request);
                Log()->Error(APP_LOG_EMERG, 0, E.what());
            }
        }
        //--------------------------------------------------------------------------------------------------------------

        void CWebService::Execute(CHTTPServerConnection *AConnection) {
            int i = 0;

            auto LRequest = AConnection->Request();
            auto LReply = AConnection->Reply();
#ifdef _DEBUG
            DebugConnection(AConnection);
#endif
            LReply->Clear();
            LReply->ContentType = CReply::json;

            CMethodHandler *Handler;
            for (i = 0; i < m_Methods.Count(); ++i) {
                Handler = (CMethodHandler *) m_Methods.Objects(i);
                if (Handler->Allow()) {
                    const CString& Method = m_Methods.Strings(i);
                    if (Method == LRequest->Method) {
                        CORS(AConnection);
                        Handler->Handler(AConnection);
                        break;
                    }
                }
            }

            if (i == m_Methods.Count()) {
                AConnection->SendStockReply(CReply::not_implemented);
            }
        }
        //--------------------------------------------------------------------------------------------------------------

        void CWebService::BeforeExecute(Pointer Data) {

        }
        //--------------------------------------------------------------------------------------------------------------

        void CWebService::AfterExecute(Pointer Data) {

        }
        //--------------------------------------------------------------------------------------------------------------

        bool CWebService::CheckUserAgent(const CString& Value) {
            return true;
        }

    }
}
}