/*++

Programm name:

  Apostol Electro

Module Name:

  Electro.cpp

Notices:

  Module Electro

Author:

  Copyright (c) Prepodobny Alen

  mailto: alienufo@inbox.ru
  mailto: ufocomp@gmail.com

--*/

//----------------------------------------------------------------------------------------------------------------------

#include "Core.hpp"
#include "Electro.hpp"
//----------------------------------------------------------------------------------------------------------------------

#include <sstream>
#include <random>
//----------------------------------------------------------------------------------------------------------------------

extern "C++" {

namespace Apostol {

    namespace Electro {

        unsigned char random_char() {
            std::random_device rd;
            std::mt19937 gen(rd());
            std::uniform_int_distribution<> dis(0, 255);
            return static_cast<unsigned char>(dis(gen));
        }
        //--------------------------------------------------------------------------------------------------------------

        CString generate_hex(const unsigned int len) {
            CString S = CString(len, ' ');

            for (auto i = 0; i < len / 2; i++) {
                auto rc = random_char();
                ByteToHexStr(S.Data() + i * 2 * sizeof(TCHAR), S.Size(), &rc, 1);
            }

            S[8] = '-';
            S[13] = '-';
            S[18] = '-';
            S[23] = '-';

            S[14] = '7';

            return S;
        }

        //--------------------------------------------------------------------------------------------------------------

        //-- CJob ------------------------------------------------------------------------------------------------------

        //--------------------------------------------------------------------------------------------------------------

        CJob::CJob(CCollection *ACCollection) : CCollectionItem(ACCollection) {
            m_JobId = generate_hex(36);
            m_PollQuery = nullptr;
        }

        //--------------------------------------------------------------------------------------------------------------

        //-- CJobManager -----------------------------------------------------------------------------------------------

        //--------------------------------------------------------------------------------------------------------------

        CJob *CJobManager::Get(int Index) {
            return (CJob *) inherited::GetItem(Index);
        }
        //--------------------------------------------------------------------------------------------------------------

        void CJobManager::Set(int Index, CJob *Value) {
            inherited::SetItem(Index, (CCollectionItem *) Value);
        }
        //--------------------------------------------------------------------------------------------------------------

        CJob *CJobManager::Add(CPQPollQuery *Query) {
            auto LJob = new CJob(this);
            LJob->PollQuery(Query);
            return LJob;
        }
        //--------------------------------------------------------------------------------------------------------------

        CJob *CJobManager::FindJobById(const CString &Id) {
            CJob *LJob = nullptr;
            for (int I = 0; I < Count(); ++I) {
                LJob = Get(I);
                if (LJob->JobId() == Id)
                    break;
            }
            return LJob;
        }
        //--------------------------------------------------------------------------------------------------------------

        CJob *CJobManager::FindJobByQuery(CPQPollQuery *Query) {
            CJob *LJob = nullptr;
            for (int I = 0; I < Count(); ++I) {
                LJob = Get(I);
                if (LJob->PollQuery() == Query)
                    break;
            }
            return LJob;
        }

        //--------------------------------------------------------------------------------------------------------------

        //-- CElectro --------------------------------------------------------------------------------------------------

        //--------------------------------------------------------------------------------------------------------------

        CElectro::CElectro(CModuleManager *AManager) : CApostolModule(AManager) {
            m_Jobs = new CJobManager();
        }
        //--------------------------------------------------------------------------------------------------------------

        CElectro::~CElectro() {
            delete m_Jobs;
        }
        //--------------------------------------------------------------------------------------------------------------

        void CElectro::RowToJson(const CStringList &Row, CString &Json) {
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

        void CElectro::PQResultToJson(CPQResult *Result, CString &Json) {
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

        void CElectro::ResultToJson(const CQueryResult &Result, CString &Json) {

            if ((Result.Count() > 0) && (Result.Count() <= 2)) {

                int Index = 0;

                const CString &VResult = Result[Index][0].Values("result");

                if (VResult.IsEmpty()) {
                    throw Delphi::Exception::EDBError(_T("Not found result in request!"));
                }

                if (Result.Count() == 2) {

                    if (VResult == "t") {

                        Json = "{\"result\": [";

                        Index++;

                        for (int Row = 0; Row < Result[Index].Count(); ++Row) {

                            const CString &VRun = Result[Index][Row].Values("run");

                            if (!VRun.IsEmpty()) {
                                if (Row != 0)
                                    Json += ", ";
                                Json += VRun;

                            } else
                                throw Delphi::Exception::EDBError(_T("Not found run in request!"));
                        }

                        Json += "]}";

                    } else {

                        const CString &VError = Result[Index][0].Values("error");
                        if (!VError.IsEmpty()) {
                            Log()->Postgres(APP_LOG_EMERG, VError.c_str());
                        }

                        RowToJson(Result[Index][0], Json);
                    }

                } else {

                    const CString &VError = Result[Index][0].Values("error");
                    if (!VError.IsEmpty()) {
                        Log()->Postgres(APP_LOG_EMERG, VError.c_str());
                    }

                    RowToJson(Result[Index][0], Json);
                }
            } else {
                throw Delphi::Exception::EDBError(_T("Invalid record count!"));
            }
        }
        //--------------------------------------------------------------------------------------------------------------

        void CElectro::InitResult(CPQPollQuery *APollQuery, CQueryResult &AResult) {
            CPQResult *LResult = nullptr;
            CStringList LFields;

            for (int i = 0; i < APollQuery->ResultCount(); ++i) {
                LResult = APollQuery->Results(i);

                if (LResult->ExecStatus() == PGRES_TUPLES_OK || LResult->ExecStatus() == PGRES_SINGLE_TUPLE) {

                    LFields.Clear();
                    for (int I = 0; I < LResult->nFields(); ++I) {
                        LFields.Add(LResult->fName(I));
                    }

                    AResult.Add(TList<CStringList>());
                    for (int Row = 0; Row < LResult->nTuples(); ++Row) {
                        AResult[i].Add(CStringList());
                        for (int Col = 0; Col < LResult->nFields(); ++Col) {
                            if (LResult->GetIsNull(Row, Col)) {
                                AResult[i].Last().AddPair(LFields[Col].c_str(), "<null>");
                            } else {
                                if (LResult->fFormat(Col) == 0) {
                                    AResult[i].Last().AddPair(LFields[Col].c_str(), LResult->GetValue(Row, Col));
                                } else {
                                    AResult[i].Last().AddPair(LFields[Col].c_str(), "<binary>");
                                }
                            }
                        }
                    }
                } else {
                    throw Delphi::Exception::EDBError(LResult->GetErrorMessage());
                }
            }
        }
        //--------------------------------------------------------------------------------------------------------------

        void CElectro::QueryToJson(CPQPollQuery *Query, CString& Json) {

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

        void CElectro::ExceptionToJson(Delphi::Exception::Exception *AException, CString &Json) {

            LPCTSTR lpMessage = AException->what();
            CString Message;
            TCHAR ch = 0;

            while (*lpMessage) {
                ch = *lpMessage++;
                if ((ch == '"') || (ch == '\\')) {
                    Message.Append('\\');
                }
                Message.Append(ch);
            }

            Json.Format(R"({"error": {"errors": [{"domain": "%s", "reason": "%s", "message": "%s", "locationType": "%s",
                            "location": "%s"}], "code": %u, "message": "%s"}})",
                            "module", "exception", Message.c_str(),
                            "SQL", "Electro", 500, "Internal Server Error");
        }
        //--------------------------------------------------------------------------------------------------------------

        void CElectro::DoPostgresQueryExecuted(CPQPollQuery *APollQuery) {
            clock_t start = clock();

            auto LConnection = dynamic_cast<CHTTPServerConnection *> (APollQuery->PollConnection());

            if (LConnection != nullptr) {

                auto LReply = LConnection->Reply();

                CReply::status_type LStatus = CReply::internal_server_error;

                try {
                    QueryToJson(APollQuery, LReply->Content);
                    LStatus = CReply::ok;
                } catch (Delphi::Exception::Exception &E) {
                    ExceptionToJson(&E, LReply->Content);
                    Log()->Error(APP_LOG_EMERG, 0, E.what());
                }

                LConnection->SendReply(LStatus, nullptr, true);

            } else {

                auto LJob = m_Jobs->FindJobByQuery(APollQuery);

                if (LJob != nullptr) {
                    try {
                        QueryToJson(APollQuery, LJob->Result());
                    } catch (Delphi::Exception::Exception &E) {
                        ExceptionToJson(&E, LJob->Result());
                        Log()->Error(APP_LOG_EMERG, 0, E.what());
                    }
                }
            }

            log_debug1(APP_LOG_DEBUG_CORE, Log(), 0, _T("Query executed runtime: %.2f ms."), (double) ((clock() - start) / (double) CLOCKS_PER_SEC * 1000));
        }
        //--------------------------------------------------------------------------------------------------------------

        void CElectro::DoPostgresQueryException(CPQPollQuery *APollQuery, Delphi::Exception::Exception *AException) {
            auto LConnection = dynamic_cast<CHTTPServerConnection *> (APollQuery->PollConnection());

            if (LConnection != nullptr) {
                auto LReply = LConnection->Reply();

                CReply::status_type LStatus = CReply::internal_server_error;

                ExceptionToJson(AException, LReply->Content);

                LConnection->SendReply(LStatus);
            }

            Log()->Error(APP_LOG_EMERG, 0, AException->what());
        }
        //--------------------------------------------------------------------------------------------------------------

        bool CElectro::APIRun(CPollConnection *AConnection, const CString &Route, const CString &jsonString, const CDataBase &DataBase) {

            auto LQuery = GetQuery(AConnection);

            if (LQuery == nullptr) {
                Log()->Error(APP_LOG_ALERT, 0, "APIRun: GetQuery() failed!");
                return false;
            }

            LQuery->SQL().Add(CString());

            if (Route == "/login") {
                LQuery->SQL().Last().Format("SELECT * FROM api.run('%s', '%s'::jsonb);",
                                            Route.c_str(), jsonString.IsEmpty() ? "{}" : jsonString.c_str());
            } else if (!DataBase.Session.IsEmpty()) {
                LQuery->SQL().Last().Format("SELECT * FROM api.run('%s', '%s'::jsonb, '%s');",
                                            Route.c_str(), jsonString.IsEmpty() ? "{}" : jsonString.c_str(), DataBase.Session.c_str());
            } else {
                LQuery->SQL().Last().Format("SELECT * FROM api.login('%s', '%s');",
                                            DataBase.Username.c_str(), DataBase.Password.c_str());

                LQuery->SQL().Add(CString());
                LQuery->SQL().Last().Format("SELECT * FROM api.run('%s', '%s'::jsonb);",
                                            Route.c_str(), jsonString.IsEmpty() ? "{}" : jsonString.c_str());

                LQuery->SQL().Add("SELECT * FROM api.logout();");
            }

            if (LQuery->QueryStart() != POLL_QUERY_START_ERROR) {
                return true;
            } else {
                delete LQuery;
            }

            Log()->Error(APP_LOG_ALERT, 0, "APIRun: QueryStart() failed!");

            return false;
        }
        //--------------------------------------------------------------------------------------------------------------

        bool CElectro::ExecSQL(CPollConnection *AConnection, const CStringList &SQL,
                                 COnPQPollQueryExecutedEvent &&Executed) {

            auto LQuery = GetQuery(AConnection);

            if (LQuery == nullptr) {
                Log()->Error(APP_LOG_ALERT, 0, "ExecSQL: GetQuery() failed!");
                return false;
            }

            if (Executed != nullptr) {
                LQuery->OnPollExecuted(static_cast<COnPQPollQueryExecutedEvent &&>(Executed));
            }

            LQuery->SQL() = SQL;

            if (LQuery->QueryStart() != POLL_QUERY_START_ERROR) {
                return true;
            } else {
                delete LQuery;
            }

            Log()->Error(APP_LOG_ALERT, 0, "ExecSQL: QueryStart() failed!");

            return false;
        }
        //--------------------------------------------------------------------------------------------------------------

        void CElectro::Get(CHTTPServerConnection *AConnection) {
            auto LRequest = AConnection->Request();

            CString JobId = LRequest->Uri.SubString(1);

            if (JobId.Length() != 36) {
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

        void CElectro::Post(CHTTPServerConnection *AConnection) {
            auto LRequest = AConnection->Request();
            auto LReply = AConnection->Reply();

            int LVersion = -1;

            CStringList LUri;
            SplitColumns(LRequest->Uri.c_str(), LRequest->Uri.Size(), &LUri, '/');
            if (LUri.Count() < 2) {
                AConnection->SendStockReply(CReply::not_found);
                return;
            }

            if (LUri[1] == _T("v1")) {
                LVersion = 1;
            } else if (LUri[1] == _T("v2")) {
                LVersion = 2;
            }

            if (LUri[0] != _T("api") || (LVersion == -1)) {
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

        bool CElectro::QueryStart(CHTTPServerConnection *AConnection, const CStringList& ASQL, const CString& ACacheFile) {
            auto LQuery = GetQuery(AConnection);

            if (LQuery == nullptr) {
                AConnection->SendStockReply(CReply::internal_server_error);
                return false;
            }

            LQuery->SQL() = ASQL;

            if (LQuery->QueryStart() != POLL_QUERY_START_ERROR) {
                if (m_Version == 1) {
                    auto LJob = m_Jobs->Add(LQuery);
                    auto LReply = AConnection->Reply();

                    //LJob->CacheFile() = ACacheFile;

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

        void CElectro::Execute(CHTTPServerConnection *AConnection) {
            auto LRequest = AConnection->Request();
            auto LReply = AConnection->Reply();

            LReply->Clear();
            LReply->ContentType = CReply::json;

            if (LRequest->Method == _T("POST")) {
                Post(AConnection);
                return;
            }

            if (LRequest->Method == _T("GET")) {
                Get(AConnection);
                return;
            }

            AConnection->SendStockReply(CReply::not_implemented);
        }
        //--------------------------------------------------------------------------------------------------------------

        bool CElectro::CheckUrerArent(const CString &Value) {
            return true;
        }

    }
}
}