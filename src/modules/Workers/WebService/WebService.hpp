/*++

Program name:

  Apostol Web Service

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

    namespace Workers {

        //--------------------------------------------------------------------------------------------------------------

        //-- CWebService -----------------------------------------------------------------------------------------------

        //--------------------------------------------------------------------------------------------------------------

        class CWebService: public CApostolModule {
        private:

            CString m_Password;

            CDateTime m_FixedDate;

            CSessionManager m_SessionManager;

            void InitMethods() override;

            static void AfterQueryWS(CHTTPServerConnection *AConnection, const CString &Path, const CJSON &Payload);
            static void AfterQuery(CReply *AReply, const CString &Path, const CString &Content);

            void QueryException(CPQPollQuery *APollQuery, const std::exception &e);

            void LoadProviders();

            static void CheckAuthorizationData(CRequest *ARequest, CAuthorization &Authorization);

            CString CreateToken(const CCleanToken& CleanToken);
            CString VerifyToken(const CString &Token);

        protected:

            void DoObject(CHTTPServerConnection *AConnection, const CStringList& Routs);

            void DoSessionDisconnected(CObject *Sender);

            void DoOAuth2(CHTTPServerConnection *AConnection);
            void DoAPI(CHTTPServerConnection *AConnection);

            void DoWSSession(CHTTPServerConnection *AConnection);
            void DoWebSocket(CHTTPServerConnection *AConnection);

            void DoGet(CHTTPServerConnection *AConnection) override;
            void DoPost(CHTTPServerConnection *AConnection);

            void DoPostgresQueryExecuted(CPQPollQuery *APollQuery) override;
            void DoPostgresQueryException(CPQPollQuery *APollQuery, Delphi::Exception::Exception *AException) override;

        public:

            explicit CWebService(CModuleProcess *AProcess);

            ~CWebService() override = default;

            static class CWebService *CreateModule(CModuleProcess *AProcess) {
                return new CWebService(AProcess);
            }

            void Initialization(CModuleProcess *AProcess) override;

            void Heartbeat() override;
            void Execute(CHTTPServerConnection *AConnection) override;

            bool IsEnabled() override;
            bool CheckUserAgent(const CString& Value) override;

            bool Authorize(CHTTPServerConnection *AConnection, const CString &Session, const CString &Path);

            bool SignUp(CHTTPServerConnection *AConnection, const CString &Payload);
            bool SignIn(CHTTPServerConnection *AConnection, const CString &Payload, const CString &Agent, const CString &Host);

            void AuthFetch(CHTTPServerConnection *AConnection, const CAuthorization &Authorization,
                           const CString &Path, const CString &Payload, const CString &Agent, const CString &Host);

            void SignFetch(CHTTPServerConnection *AConnection, const CString &Path, const CString &Payload,
                           const CString &Session, const CString &Nonce, const CString &Signature, const CString &Agent,
                           const CString &Host, long int ReceiveWindow = 5000);

            static CString GetSession(CRequest *ARequest);
            static int CheckSession(CRequest *ARequest, const CString &Path, CString &Session);

            bool CheckAuthorization(CHTTPServerConnection *AConnection, CAuthorization &Authorization);

        };
    }
}

using namespace Apostol::Workers;
}
#endif //APOSTOL_WEBSERVICE_HPP
