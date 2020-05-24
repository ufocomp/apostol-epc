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
            m_Headers.Add("Authorization");

            CWebService::InitMethods();
        }
        //--------------------------------------------------------------------------------------------------------------

        void CWebService::InitMethods() {
#if defined(_GLIBCXX_RELEASE) && (_GLIBCXX_RELEASE >= 9)
            m_pMethods->AddObject(_T("GET")    , (CObject *) new CMethodHandler(true , [this](auto && Connection) { DoGet(Connection); }));
            m_pMethods->AddObject(_T("POST")   , (CObject *) new CMethodHandler(true , [this](auto && Connection) { DoPost(Connection); }));
            m_pMethods->AddObject(_T("OPTIONS"), (CObject *) new CMethodHandler(true , [this](auto && Connection) { DoOptions(Connection); }));
            m_pMethods->AddObject(_T("HEAD")   , (CObject *) new CMethodHandler(true , [this](auto && Connection) { DoHead(Connection); }));
            m_pMethods->AddObject(_T("PUT")    , (CObject *) new CMethodHandler(false, [this](auto && Connection) { MethodNotAllowed(Connection); }));
            m_pMethods->AddObject(_T("DELETE") , (CObject *) new CMethodHandler(false, [this](auto && Connection) { MethodNotAllowed(Connection); }));
            m_pMethods->AddObject(_T("TRACE")  , (CObject *) new CMethodHandler(false, [this](auto && Connection) { MethodNotAllowed(Connection); }));
            m_pMethods->AddObject(_T("PATCH")  , (CObject *) new CMethodHandler(false, [this](auto && Connection) { MethodNotAllowed(Connection); }));
            m_pMethods->AddObject(_T("CONNECT"), (CObject *) new CMethodHandler(false, [this](auto && Connection) { MethodNotAllowed(Connection); }));
#else
            m_pMethods->AddObject(_T("GET"), (CObject *) new CMethodHandler(true, std::bind(&CWebService::DoGet, this, _1)));
            m_pMethods->AddObject(_T("POST"), (CObject *) new CMethodHandler(true, std::bind(&CWebService::DoPost, this, _1)));
            m_pMethods->AddObject(_T("OPTIONS"), (CObject *) new CMethodHandler(true, std::bind(&CWebService::DoOptions, this, _1)));
            m_pMethods->AddObject(_T("HEAD"), (CObject *) new CMethodHandler(true, std::bind(&CWebService::DoHead, this, _1)));
            m_pMethods->AddObject(_T("PUT"), (CObject *) new CMethodHandler(false, std::bind(&CWebService::MethodNotAllowed, this, _1)));
            m_pMethods->AddObject(_T("DELETE"), (CObject *) new CMethodHandler(false, std::bind(&CWebService::MethodNotAllowed, this, _1)));
            m_pMethods->AddObject(_T("TRACE"), (CObject *) new CMethodHandler(false, std::bind(&CWebService::MethodNotAllowed, this, _1)));
            m_pMethods->AddObject(_T("PATCH"), (CObject *) new CMethodHandler(false, std::bind(&CWebService::MethodNotAllowed, this, _1)));
            m_pMethods->AddObject(_T("CONNECT"), (CObject *) new CMethodHandler(false, std::bind(&CWebService::MethodNotAllowed, this, _1)));
#endif
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

        void CWebService::QueryToJson(CPQPollQuery *Query, CString& Json) {

            CPQResult *Result;

            for (int I = 0; I < Query->Count(); I++) {
                Result = Query->Results(I);
                if (Result->ExecStatus() != PGRES_TUPLES_OK)
                    throw Delphi::Exception::EDBError(Result->GetErrorMessage());
            }

            if (Query->Count() == 3) {
                Result = Query->Results(0);

                if (SameText(Result->GetValue(0, 1), "f")) {
                    Log()->Error(APP_LOG_EMERG, 0, Result->GetValue(0, 2));
                    PQResultToJson(Result, Json);
                    return;
                }

                Result = Query->Results(1);
            } else {
                Result = Query->Results(0);
            }

            Json = "{\"result\": ";

            if (Result->nTuples() > 0) {

                Json += "[";
                for (int Row = 0; Row < Result->nTuples(); ++Row) {
                    for (int Col = 0; Col < Result->nFields(); ++Col) {
                        if (Row != 0)
                            Json += ", ";
                        if (Result->GetIsNull(Row, Col)) {
                            Json += "null";
                        } else {
                            Json += Result->GetValue(Row, Col);
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

                auto LJob = m_pJobs->FindJobByQuery(APollQuery);
                if (LJob == nullptr) {
                    Log()->Error(APP_LOG_EMERG, 0, _T("Job not found by Query."));
                    return;
                }

                auto LReply = &LJob->Reply();

                try {
                    QueryToJson(APollQuery, LReply->Content);
                } catch (Delphi::Exception::Exception &E) {
                    LReply->Content.Clear();
                    ExceptionToJson(0, E, LReply->Content);
                    Log()->Error(APP_LOG_EMERG, 0, E.what());
                }
            }

            log_debug1(APP_LOG_DEBUG_CORE, Log(), 0, _T("Query executed runtime: %.2f ms."), (double) ((clock() - start) / (double) CLOCKS_PER_SEC * 1000));
        }
        //--------------------------------------------------------------------------------------------------------------

        void CWebService::APIRun(CHTTPServerConnection *AConnection, const CString &Route, const CString &jsonString,
                const CAuthorization &Authorization) {

            CStringList SQL;

            SQL.Add(CString());

            if (Route == "/login") {
                SQL.Last().Format("SELECT * FROM api.run('%s', '%s'::jsonb);",
                                  Route.c_str(), jsonString.IsEmpty() ? "{}" : jsonString.c_str());
            } else if (Route == "/join") {
                SQL.Last().Format("SELECT * FROM api.login('%s', '%s');",
                                  Config()->JoinUser().c_str(), Config()->JoinPassword().c_str());

                SQL.Add(CString());
                SQL.Last().Format("SELECT * FROM api.run('%s', '%s'::jsonb);",
                                  Route.c_str(), jsonString.IsEmpty() ? "{}" : jsonString.c_str());

                SQL.Add("SELECT * FROM api.logout();");
            } else {
                if (Authorization.Schema == asBasic) {
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

            if (!StartQuery(AConnection, SQL)) {
                AConnection->SendStockReply(CReply::service_unavailable);
            }
        }
        //--------------------------------------------------------------------------------------------------------------

        void CWebService::DoObject(CHTTPServerConnection *AConnection, const CStringList &Routs) {

            auto CheckParams = [this] (const CStringList &Params, const CString &Action, CString &Route, CJSON &Json) {

                const auto& Id = Params["id"];
                if (!Id.IsEmpty())
                    Json.Object().AddPair("id", Id);

                if (Action == "method") {
                    Route << "/method";
                } else if (Action == "count") {
                    Route << "/count";
                } else {
                    if (Id.IsEmpty()) {
                        Route << "/list";
                    } else {
                        Route << "/get";
                    }
                }
            };

            auto LRequest = AConnection->Request();
            auto LReply = AConnection->Reply();

            const auto& LCommand = Routs[2].Lower();
            const auto& LAction = Routs.Count() == 4 ? Routs[3].Lower() : "";

            CString LPath;
            CJSON Json;

            if (LCommand == "whoami") {

                LPath = "/";
                LPath += LCommand;

            } else if (LCommand == "current" && !LAction.IsEmpty()) {

                LPath = "/";
                LPath += LCommand;
                LPath += "/";
                LPath += LAction;

            } else if (LCommand == "method") {

                LPath = "/";
                LPath += LCommand;

                if (LAction == "get") {

                    LPath += "/get";

                    const auto& Object = LRequest->Params["object"];
                    const auto& Class = LRequest->Params["class"];
                    const auto& State = LRequest->Params["state"];
                    const auto& ClassCode = LRequest->Params["classcode"];
                    const auto& StateCode = LRequest->Params["statecode"];

                    auto& jsonObject = Json.Object();

                    if (!Object.IsEmpty())
                        jsonObject.AddPair("object", Object);

                    if (!State.IsEmpty())
                        jsonObject.AddPair("state", State);

                    if (!Class.IsEmpty())
                        jsonObject.AddPair("class", Class);

                    if (!ClassCode.IsEmpty())
                        jsonObject.AddPair("classcode", ClassCode);

                    if (!StateCode.IsEmpty())
                        jsonObject.AddPair("statecode", StateCode);
                } else if (!LAction.IsEmpty()) {
                    AConnection->SendStockReply(CReply::not_found);
                    return;
                }

            } else if (LCommand == "client" || LCommand == "card" || LCommand == "charge_point" || LCommand == "contract" || LCommand == "address") {
                LPath = "/";
                LPath += LCommand;
                CheckParams(LRequest->Params, LAction, LPath, Json);
            } else {
                AConnection->SendStockReply(CReply::not_found);
                return;
            }

            try {
                const auto& LAuthorization = LRequest->Headers.Values(_T("authorization"));
                CAuthorization Authorization(LAuthorization);

                if (Authorization.Schema != asUnknown) {
                    APIRun(AConnection, LPath, Json.ToString(), Authorization);
                } else {
                    AConnection->SendStockReply(CReply::unauthorized);
                }
            } catch (Delphi::Exception::Exception &E) {
                ExceptionToJson(0, E, LReply->Content);
                AConnection->CloseConnection(true);
                AConnection->SendReply(CReply::bad_request);
                Log()->Error(APP_LOG_EMERG, 0, E.what());
            }
        }
        //--------------------------------------------------------------------------------------------------------------

        void CWebService::DoAPI(CHTTPServerConnection *AConnection) {
            auto LRequest = AConnection->Request();
            auto LReply = AConnection->Reply();

            LReply->ContentType = CReply::json;

            CStringList LRouts;
            SplitColumns(LRequest->Location.pathname, LRouts, '/');

            if (LRouts.Count() < 3) {
                AConnection->SendStockReply(CReply::not_found);
                return;
            }

            const auto& LService = LRouts[0].Lower();
            const auto& LVersion = LRouts[1].Lower();
            const auto& LCommand = LRouts[2].Lower();

            if (LVersion == "v1") {
                m_Version = 1;
            } else if (LVersion == "v2") {
                m_Version = 2;
            }

            if (LService != "api" || (m_Version == -1)) {
                AConnection->SendStockReply(CReply::not_found);
                return;
            }

            try {
                if (LCommand == "ping") {

                    AConnection->SendStockReply(CReply::ok);

                } else if (LCommand == "time") {

                    LReply->Content << "{\"serverTime\": " << to_string(MsEpoch()) << "}";

                    AConnection->SendReply(CReply::ok);

                } else if (m_Version == 2) {

                    if (LRouts.Count() != 3) {
                        AConnection->SendStockReply(CReply::bad_request);
                        return;
                    }

                    const auto& Identity = LRouts[2];

                    if (Identity.Length() != APOSTOL_MODULE_UID_LENGTH) {
                        AConnection->SendStockReply(CReply::bad_request);
                        return;
                    }

                    auto LJob = m_pJobs->FindJobById(Identity);

                    if (LJob == nullptr) {
                        AConnection->SendStockReply(CReply::not_found);
                        return;
                    }

                    if (LJob->Reply().Content.IsEmpty()) {
                        AConnection->SendStockReply(CReply::no_content);
                        return;
                    }

                    LReply->Content = LJob->Reply().Content;

                    CReply::GetReply(LReply, CReply::ok);

                    LReply->Headers << LJob->Reply().Headers;

                    AConnection->SendReply();

                    delete LJob;

                } else {

                    DoObject(AConnection, LRouts);

                }
            } catch (std::exception &e) {
                ExceptionToJson(0, e, LReply->Content);

                AConnection->CloseConnection(true);
                AConnection->SendReply(CReply::bad_request);

                Log()->Error(APP_LOG_EMERG, 0, e.what());
            }
        }
        //--------------------------------------------------------------------------------------------------------------

        void CWebService::DoGet(CHTTPServerConnection *AConnection) {
            auto LRequest = AConnection->Request();

            CString LPath(LRequest->Location.pathname);

            // Request path must be absolute and not contain "..".
            if (LPath.empty() || LPath.front() != '/' || LPath.find("..") != CString::npos) {
                AConnection->SendStockReply(CReply::bad_request);
                return;
            }

            if (LPath.SubString(0, 5) == "/api/") {
                DoAPI(AConnection);
                return;
            }

            SendResource(AConnection, LPath);
        }
        //--------------------------------------------------------------------------------------------------------------

        void CWebService::DoPost(CHTTPServerConnection *AConnection) {
            auto LRequest = AConnection->Request();
            auto LReply = AConnection->Reply();

            LReply->ContentType = CReply::json;

            CStringList LRouts;
            SplitColumns(LRequest->Location.pathname, LRouts, '/');
            if (LRouts.Count() < 2) {
                AConnection->SendStockReply(CReply::not_found);
                return;
            }

            if (LRouts[1] == _T("v1")) {
                m_Version = 1;
            } else if (LRouts[1] == _T("v2")) {
                m_Version = 2;
            }

            if (LRouts[0] != _T("api") || (m_Version == -1)) {
                AConnection->SendStockReply(CReply::not_found);
                return;
            }

            CString LPath;
            for (int I = 2; I < LRouts.Count(); ++I) {
                LPath.Append('/');
                LPath.Append(LRouts[I].Lower());
            }

            if (LPath.IsEmpty()) {
                AConnection->SendStockReply(CReply::not_found);
                return;
            }

            try {
                const auto& LAuthorization = LRequest->Headers.Values(_T("authorization"));
                const auto& Authorization = LAuthorization.IsEmpty() ? CAuthorization() : CAuthorization(LAuthorization);
                if (Authorization.Schema != asUnknown) {
                    APIRun(AConnection, LPath, LRequest->Content, Authorization);
                } else if (LPath == "/login" || LPath == "/join") {
                    APIRun(AConnection, LPath, LRequest->Content, Authorization);
                } else {
                    AConnection->SendStockReply(CReply::unauthorized);
                }
            } catch (Delphi::Exception::Exception &E) {
                ExceptionToJson(0, E, LReply->Content);
                AConnection->CloseConnection(true);
                AConnection->SendReply(CReply::bad_request);
                Log()->Error(APP_LOG_EMERG, 0, E.what());
            }
        }
        //--------------------------------------------------------------------------------------------------------------

        bool CWebService::CheckUserAgent(const CString& Value) {
            return true;
        }

    }
}
}