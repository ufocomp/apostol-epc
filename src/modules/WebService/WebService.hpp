/*++

Program name:

  Apostol Electro

Module Name:

  WebService.hpp

Notices:

  Module WebService 

Author:

  Copyright (c) Prepodobny Alen

  mailto: alienufo@inbox.ru
  mailto: ufocomp@gmail.com

--*/

#ifndef APOSTOL_WEBSERVICE_HPP
#define APOSTOL_WEBSERVICE_HPP
//----------------------------------------------------------------------------------------------------------------------

extern "C++" {

namespace Apostol {

    namespace WebService {

        typedef struct CDataBase {
            CString Username;
            CString Password;
            CString Session;
        } CDataBase;

        //--------------------------------------------------------------------------------------------------------------

        //-- CWebService -----------------------------------------------------------------------------------------------

        //--------------------------------------------------------------------------------------------------------------

        class CWebService: public CApostolModule {
        private:

            int m_Version;

            CJobManager *m_Jobs;

            static void DebugRequest(CRequest *ARequest);
            static void DebugReply(CReply *AReply);

            static void PQResultToJson(CPQResult *Result, CString& Json);
            static void QueryToJson(CPQPollQuery *Query, CString& Json);

            bool QueryStart(CHTTPServerConnection *AConnection, const CStringList& SQL);
            bool APIRun(CHTTPServerConnection *AConnection, const CString &Route, const CString &jsonString, const CDataBase &DataBase);

        protected:

            void DoGet(CHTTPServerConnection *AConnection);
            void DoPost(CHTTPServerConnection *AConnection);

            static void DoWWW(CHTTPServerConnection *AConnection);

            void DoPostgresQueryExecuted(CPQPollQuery *APollQuery) override;
            void DoPostgresQueryException(CPQPollQuery *APollQuery, Delphi::Exception::Exception *AException) override;

            static void ExceptionToJson(int ErrorCode, const std::exception &AException, CString& Json);

        public:

            explicit CWebService(CModuleManager *AManager);

            ~CWebService() override;

            static class CWebService *CreateModule(CModuleManager *AManager) {
                return new CWebService(AManager);
            }

            void InitMethods() override;

            void BeforeExecute(Pointer Data) override;
            void AfterExecute(Pointer Data) override;

            void Execute(CHTTPServerConnection *AConnection) override;

            bool CheckUserAgent(const CString& Value) override;

        };

    }
}

using namespace Apostol::WebService;
}
#endif //APOSTOL_WEBSERVICE_HPP
