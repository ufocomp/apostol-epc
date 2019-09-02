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

        typedef struct CDataBase {
            CString Username;
            CString Password;
            CString Session;
        } CDataBase;
        //--------------------------------------------------------------------------------------------------------------

        class CElectro: public CApostolModule {
        private:

            int m_Version;

            CJobManager *m_Jobs;

            static void RowToJson(const CStringList& Row, CString& Json);
            static void PQResultToJson(CPQResult *Result, CString& Json);
            static void ExceptionToJson(Delphi::Exception::Exception *AException, CString& Json);

            void QueryToJson(CPQPollQuery *Query, CString& Json);

            bool QueryStart(CHTTPServerConnection *AConnection, const CStringList& ASQL);

            bool APIRun(CHTTPServerConnection *AConnection, const CString &Route, const CString &jsonString, const CDataBase &DataBase);

        protected:

            void InitHeaders() override;

            void DoGet(CHTTPServerConnection *AConnection);
            void DoPost(CHTTPServerConnection *AConnection);

            void DoPostgresQueryExecuted(CPQPollQuery *APollQuery) override;
            void DoPostgresQueryException(CPQPollQuery *APollQuery, Delphi::Exception::Exception *AException) override;

        public:

            explicit CElectro(CModuleManager *AManager);

            ~CElectro() override;

            static class CElectro *CreateModule(CModuleManager *AManager) {
                return new CElectro(AManager);
            }

            void Execute(CHTTPServerConnection *AConnection) override;

            bool CheckUrerArent(const CString& Value) override;

        };

    }
}

using namespace Apostol::Electro;
}
#endif //APOSTOL_ADDSERVER_HPP
