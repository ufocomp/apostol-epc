/*++

Programm name:

  Apostol Electro

Module Name:

  Electro.hpp

Notices:

  Module Electro 

Author:

  Copyright (c) Prepodobny Alen

  mailto: alienufo@inbox.ru
  mailto: ufocomp@gmail.com

--*/

#ifndef APOSTOL_ADDSERVER_HPP
#define APOSTOL_ADDSERVER_HPP
//----------------------------------------------------------------------------------------------------------------------

extern "C++" {

namespace Apostol {

    namespace Electro {

        typedef TList<TList<CStringList>> CQueryResult;
        //--------------------------------------------------------------------------------------------------------------

        typedef struct CDataBase {
            CString Username;
            CString Password;
            CString Session;
        } CDataBase;
        //--------------------------------------------------------------------------------------------------------------

        class CJob: CCollectionItem {
        private:

            CString m_JobId;

            CString m_Result;

            CString m_CacheFile;

            CPQPollQuery *m_PollQuery;

        public:

            explicit CJob(CCollection *ACCollection);

            ~CJob() override = default;

            CString& JobId() { return m_JobId; };
            const CString& JobId() const { return m_JobId; };

            CString& CacheFile() { return m_CacheFile; };
            const CString& CacheFile() const { return m_CacheFile; };

            CString& Result() { return m_Result; }
            const CString& Result() const { return m_Result; }

            CPQPollQuery *PollQuery() { return m_PollQuery; };
            void PollQuery(CPQPollQuery *Value) { m_PollQuery = Value; };
        };
        //--------------------------------------------------------------------------------------------------------------

        class CJobManager: CCollection {
            typedef CCollection inherited;
        private:

            CJob *Get(int Index);
            void Set(int Index, CJob *Value);

        public:

            CJobManager(): CCollection(this) {

            }

            CJob *Add(CPQPollQuery *Query);

            CJob *FindJobById(const CString &Id);
            CJob *FindJobByQuery(CPQPollQuery *Query);

            CJob *Jobs(int Index) { return Get(Index); }
            void Jobs(int Index, CJob *Value) { Set(Index, Value); }

        };
        //--------------------------------------------------------------------------------------------------------------

        class CElectro: public CApostolModule {
        private:

            int m_Version;

            CJobManager *m_Jobs;

            void InitResult(CPQPollQuery *APollQuery, CQueryResult& AResult);

            void ExceptionToJson(Delphi::Exception::Exception *AException, CString& Json);

            void ResultToJson(const CQueryResult& Result, CString& Json);
            void RowToJson(const CStringList& Row, CString& Json);

            void PQResultToJson(CPQResult *Result, CString& Json);
            void QueryToJson(CPQPollQuery *Query, CString& Json);

            bool QueryStart(CHTTPServerConnection *AConnection, const CStringList& ASQL, const CString& ACacheFile);

        protected:

            void Post(CHTTPServerConnection *AConnection);
            void Get(CHTTPServerConnection *AConnection);

            void DoPostgresQueryExecuted(CPQPollQuery *APollQuery) override;
            void DoPostgresQueryException(CPQPollQuery *APollQuery, Delphi::Exception::Exception *AException) override;

        public:

            explicit CElectro(CModuleManager *AManager);

            ~CElectro() override;

            static class CElectro *CreateModule(CModuleManager *AManager) {
                return new CElectro(AManager);
            }

            void Execute(CHTTPServerConnection *AConnection) override;

            bool APIRun(CPollConnection *AConnection, const CString &Route, const CString &jsonString, const CDataBase &DataBase);

            bool ExecSQL(CPollConnection *AConnection, const CStringList &SQL, COnPQPollQueryExecutedEvent &&Executed = nullptr);

            bool CheckUrerArent(const CString& Value) override;

        };

    }
}

using namespace Apostol::Electro;
}
#endif //APOSTOL_ADDSERVER_HPP
