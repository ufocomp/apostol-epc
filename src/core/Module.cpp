/*++

Library name:

  apostol-core

Module Name:

  Module.cpp

Notices:

  Apostol Core

Author:

  Copyright (c) Prepodobny Alen

  mailto: alienufo@inbox.ru
  mailto: ufocomp@gmail.com

--*/

#include "Core.hpp"
#include "Module.hpp"
//----------------------------------------------------------------------------------------------------------------------

#include <sstream>
#include <random>
//----------------------------------------------------------------------------------------------------------------------

extern "C++" {

namespace Apostol {

    namespace Module {

        unsigned char random_char() {
            std::random_device rd;
            std::mt19937 gen(rd());
            std::uniform_int_distribution<> dis(0, 255);
            return static_cast<unsigned char>(dis(gen));
        }
        //--------------------------------------------------------------------------------------------------------------

//      A0000-P0000-O0000-S0000-T0000-O0000-L0000
//      01234567890123456789012345678901234567890
//      0         1         2         3         4
        CString generate_hex(const unsigned int len) {
            CString S(len, ' ');

            for (auto i = 0; i < len / 2; i++) {
                unsigned char rc = random_char();
                ByteToHexStr(S.Data() + i * 2 * sizeof(unsigned char), S.Size(), &rc, 1);
            }

            S[ 0] = 'A';
            S[ 5] = '-';
            S[ 6] = 'P';
            S[11] = '-';
            S[12] = 'O';
            S[17] = '-';
            S[18] = 'S';
            S[23] = '-';
            S[24] = 'T';
            S[29] = '-';
            S[30] = 'O';
            S[35] = '-';
            S[36] = 'L';

            return S;
        }

        //--------------------------------------------------------------------------------------------------------------

        //-- CJob ------------------------------------------------------------------------------------------------------

        //--------------------------------------------------------------------------------------------------------------

        CJob::CJob(CCollection *ACCollection) : CCollectionItem(ACCollection) {
            m_JobId = generate_hex(APOSTOL_MODULE_JOB_ID_LENGTH);
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

        //-- CApostolModule --------------------------------------------------------------------------------------------

        //--------------------------------------------------------------------------------------------------------------

        CApostolModule::CApostolModule(): CApostolModule(Application::Application) {

        }
        //--------------------------------------------------------------------------------------------------------------

        CApostolModule::CApostolModule(CModuleManager *AManager): CCollectionItem(AManager), CGlobalComponent() {
            m_Headers = new CStringList(true);
            InitHeaders();
        }
        //--------------------------------------------------------------------------------------------------------------

        CApostolModule::~CApostolModule() {
            delete m_Headers;
        }
        //--------------------------------------------------------------------------------------------------------------

        void CApostolModule::InitHeaders() {
            m_Headers->AddObject(_T("GET"), (CObject *) new CHeaderHandler(false, std::bind(&CApostolModule::MethodNotAllowed, this, _1)));
            m_Headers->AddObject(_T("POST"), (CObject *) new CHeaderHandler(false, std::bind(&CApostolModule::MethodNotAllowed, this, _1)));
            m_Headers->AddObject(_T("OPTIONS"), (CObject *) new CHeaderHandler(true, std::bind(&CApostolModule::DoOptions, this, _1)));
            m_Headers->AddObject(_T("PUT"), (CObject *) new CHeaderHandler(false, std::bind(&CApostolModule::MethodNotAllowed, this, _1)));
            m_Headers->AddObject(_T("DELETE"), (CObject *) new CHeaderHandler(false, std::bind(&CApostolModule::MethodNotAllowed, this, _1)));
            m_Headers->AddObject(_T("TRACE"), (CObject *) new CHeaderHandler(false, std::bind(&CApostolModule::MethodNotAllowed, this, _1)));
            m_Headers->AddObject(_T("HEAD"), (CObject *) new CHeaderHandler(false, std::bind(&CApostolModule::MethodNotAllowed, this, _1)));
            m_Headers->AddObject(_T("PATCH"), (CObject *) new CHeaderHandler(false, std::bind(&CApostolModule::MethodNotAllowed, this, _1)));
            m_Headers->AddObject(_T("CONNECT"), (CObject *) new CHeaderHandler(false, std::bind(&CApostolModule::MethodNotAllowed, this, _1)));
        }
        //--------------------------------------------------------------------------------------------------------------

        const CString &CApostolModule::GetAllowedMethods(CString &AllowedMethods) const {
            if (AllowedMethods.IsEmpty()) {
                if (m_Headers->Count() > 0) {
                    CHeaderHandler *Handler;
                    for (int i = 0; i < m_Headers->Count(); ++i) {
                        Handler = (CHeaderHandler *) m_Headers->Objects(i);
                        if (Handler->Allow()) {
                            if (AllowedMethods.IsEmpty())
                                AllowedMethods = m_Headers->Strings(i);
                            else
                                AllowedMethods += _T(", ") + m_Headers->Strings(i);
                        }
                    }
                }
            }
            return AllowedMethods;
        }
        //--------------------------------------------------------------------------------------------------------------

        void CApostolModule::MethodNotAllowed(CHTTPServerConnection *AConnection) {
            auto LReply = AConnection->Reply();

            CReply::GetStockReply(LReply, CReply::not_allowed);

            if (!AllowedMethods().IsEmpty())
                LReply->AddHeader(_T("Allow"), AllowedMethods().c_str());

            AConnection->SendReply();
        }
        //--------------------------------------------------------------------------------------------------------------

        void CApostolModule::DoOptions(CHTTPServerConnection *AConnection) {
            auto LReply = AConnection->Reply();
#ifdef _DEBUG
            auto LRequest = AConnection->Request();
            if (LRequest->Uri == _T("/quit"))
                Application::Application->SignalProcess()->Quit();
#endif
            CReply::GetStockReply(LReply, CReply::ok);

            if (!AllowedMethods().IsEmpty())
                LReply->AddHeader(_T("Allow"), AllowedMethods().c_str());

            AConnection->SendReply();
        }
        //--------------------------------------------------------------------------------------------------------------

        void CApostolModule::QueryToResult(CPQPollQuery *APollQuery, CQueryResult &AResult) {
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

        CPQPollQuery *CApostolModule::GetQuery(CPollConnection *AConnection) {
            CPQPollQuery *LQuery = Application::Application->GetQuery(AConnection);

            if (Assigned(LQuery)) {
                LQuery->OnPollExecuted(std::bind(&CApostolModule::DoPostgresQueryExecuted, this, _1));
                LQuery->OnException(std::bind(&CApostolModule::DoPostgresQueryException, this, _1, _2));
            }

            return LQuery;
        }
        //--------------------------------------------------------------------------------------------------------------

        bool CApostolModule::ExecSQL(CPollConnection *AConnection, const CStringList &SQL,
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

        //-- CModuleManager --------------------------------------------------------------------------------------------

        //--------------------------------------------------------------------------------------------------------------

        bool CModuleManager::ExecuteModule(CHTTPServerConnection *AConnection) {

            CApostolModule *LModule = nullptr;

            auto LRequest = AConnection->Request();

            const CString &UserAgent = LRequest->Headers.Values(_T("user-agent"));

            int Index = 0;
            while (Index < ModuleCount() && !Modules(Index)->CheckUrerArent(UserAgent))
                Index++;

            if (Index == ModuleCount()) {
                AConnection->SendStockReply(CReply::forbidden);
                return false;
            }

            LModule = Modules(Index);

            DoBeforeExecuteModule(LModule);
            try {
                LModule->Execute(AConnection);
            } catch (...) {
                AConnection->SendStockReply(CReply::internal_server_error);
                DoAfterExecuteModule(LModule);
                throw;
            }
            DoAfterExecuteModule(LModule);

            return true;
        }
        //--------------------------------------------------------------------------------------------------------------

    }
}
}
