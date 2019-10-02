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

extern "C++" {

namespace Apostol {

    namespace Module {

        //--------------------------------------------------------------------------------------------------------------

        //-- CWebService --------------------------------------------------------------------------------------------------

        //--------------------------------------------------------------------------------------------------------------

        CWebService::CWebService(CModuleManager *AManager) : CApostolModule(AManager) {
            m_Version = -1;
            m_Jobs = new CJobManager();
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

        void CWebService::ExceptionToJson(int ErrorCode, Delphi::Exception::Exception *AException, CString& Json) {

            TCHAR ch;
            LPCTSTR lpMessage = AException->what();
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

                ExceptionToJson(0, AException, LReply->Content);

                LConnection->SendReply(LStatus);
            }

            Log()->Error(APP_LOG_EMERG, 0, AException->what());
        }
        //--------------------------------------------------------------------------------------------------------------

        void CWebService::RowToJson(const CStringList &Row, CString &Json) {
            Json = "{";

            for (int I = 0; I < Row.Count(); ++I) {
                if (I > 0) {
                    Json += ", ";
                }

                const CString &Name = Row.Names(I);
                const CString &Value = Row.Values(Name);

                Json += "\"";
                Json += Name;
                Json += "\"";

                if (Name == _T("session")) {
                    Json += ": ";
                    if (Value == _T("<null>")) {
                        Json += _T("null");
                    } else {
                        Json += "\"";
                        Json += Value;
                        Json += "\"";
                    }
                } else if (Name == _T("result")) {
                    Json += ": ";
                    if (Value == _T("t")) {
                        Json += _T("true");
                    } else {
                        Json += _T("false");
                    }
                } else {
                    Json += ": \"";
                    Json += Value;
                    Json += "\"";
                }
            }

            Json += "}";
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
                    ExceptionToJson(0, &E, LReply->Content);
                    Log()->Error(APP_LOG_EMERG, 0, E.what());
                }

                LConnection->SendReply(LStatus, nullptr, true);

            } else {

                auto LJob = m_Jobs->FindJobByQuery(APollQuery);

                if (LJob != nullptr) {
                    try {
                        QueryToJson(APollQuery, LJob->Result());
                    } catch (Delphi::Exception::Exception &E) {
                        ExceptionToJson(0, &E, LJob->Result());
                        Log()->Error(APP_LOG_EMERG, 0, E.what());
                    }
                }
            }

            log_debug1(APP_LOG_DEBUG_CORE, Log(), 0, _T("Query executed runtime: %.2f ms."), (double) ((clock() - start) / (double) CLOCKS_PER_SEC * 1000));
        }
        //--------------------------------------------------------------------------------------------------------------

        bool CWebService::QueryStart(CHTTPServerConnection *AConnection, const CStringList& ASQL) {
            auto LQuery = GetQuery(AConnection);

            if (LQuery == nullptr) {
                Log()->Error(APP_LOG_ALERT, 0, "QueryStart: GetQuery() failed!");
                AConnection->SendStockReply(CReply::internal_server_error);
                return false;
            }

            LQuery->SQL() = ASQL;

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
                const CDataBase &DataBase) {

            CStringList SQL;

            SQL.Add(CString());

            if (Route == "/login") {
                SQL.Last().Format("SELECT * FROM api.run('%s', '%s'::jsonb);",
                                            Route.c_str(), jsonString.IsEmpty() ? "{}" : jsonString.c_str());
            } else if (!DataBase.Session.IsEmpty()) {
                SQL.Last().Format("SELECT * FROM api.run('%s', '%s'::jsonb, '%s');",
                                            Route.c_str(), jsonString.IsEmpty() ? "{}" : jsonString.c_str(), DataBase.Session.c_str());
            } else {
                SQL.Last().Format("SELECT * FROM api.login('%s', '%s');",
                                            DataBase.Username.c_str(), DataBase.Password.c_str());

                SQL.Add(CString());
                SQL.Last().Format("SELECT * FROM api.run('%s', '%s'::jsonb);",
                                            Route.c_str(), jsonString.IsEmpty() ? "{}" : jsonString.c_str());

                SQL.Add("SELECT * FROM api.logout();");
            }

            return QueryStart(AConnection, SQL);
        }
        //--------------------------------------------------------------------------------------------------------------

        void CWebService::DoGet(CHTTPServerConnection *AConnection) {
            auto LRequest = AConnection->Request();

            CString JobId = LRequest->Uri.SubString(1);

            if (JobId.Length() != APOSTOL_MODULE_UID_LENGTH) {
                AConnection->SendStockReply(CReply::bad_request);
                return;
            }

            auto LJob = m_Jobs->FindJobById(JobId);

            if (LJob == nullptr) {
                AConnection->SendStockReply(CReply::not_found);
                return;
            }

            if (LJob->Result().IsEmpty()) {
                AConnection->SendStockReply(CReply::accepted);
                return;
            }

            auto LReply = AConnection->Reply();

            LReply->Content = LJob->Result();

            AConnection->SendReply(CReply::ok);

            delete LJob;
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
                LRoute.Append(LUri[I]);
            }

            const CString &LAuthorization = LRequest->Headers.Values(_T("authorization"));

            if (LAuthorization.IsEmpty()) {
                if (LRoute.Lower() == "/login") {
                    if (!APIRun(AConnection, LRoute, LRequest->Content, CDataBase())) {
                        AConnection->SendStockReply(CReply::internal_server_error);
                    }
                    return;
                } else {
                    AConnection->SendStockReply(CReply::unauthorized);
                    return;
                }
            }

            if (LAuthorization.SubString(0, 5).Lower() == "basic") {
                const CString LPassphrase(base64_decode(LAuthorization.SubString(6)));

                const size_t LPos = LPassphrase.Find(':');
                if (LPos == CString::npos) {
                    AConnection->SendStockReply(CReply::bad_request);
                    return;
                }

                const CDataBase LDataBase = { LPassphrase.SubString(0, LPos), LPassphrase.SubString(LPos + 1) };

                if (LDataBase.Username.IsEmpty() || LDataBase.Password.IsEmpty()) {
                    AConnection->SendStockReply(CReply::bad_request);
                    return;
                }

                if (!APIRun(AConnection, LRoute, LRequest->Content, LDataBase)) {
                    AConnection->SendStockReply(CReply::internal_server_error);
                    return;
                }
            } else if (LAuthorization.SubString(0, 7).Lower() == "session") {
                const CDataBase LDataBase = { CString(), CString(), LAuthorization.SubString(8, 40) };

                if (LDataBase.Session.Length() != 40) {
                    AConnection->SendStockReply(CReply::bad_request);
                    return;
                }

                if (!APIRun(AConnection, LRoute, LRequest->Content, LDataBase)) {
                    AConnection->SendStockReply(CReply::internal_server_error);
                    return;
                }

                LReply->AddHeader(_T("Authorization"), _T("session "));
                LReply->Headers.Last().Value += LDataBase.Session;
            } else {
                AConnection->SendStockReply(CReply::bad_request);
            }
        }
        //--------------------------------------------------------------------------------------------------------------

        void CWebService::Execute(CHTTPServerConnection *AConnection) {
            int i = 0;
            auto LRequest = AConnection->Request();
            auto LReply = AConnection->Reply();

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