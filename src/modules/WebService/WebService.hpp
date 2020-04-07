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

        enum CAuthorizationSchemes { asUnknown, asBasic, asSession };

        typedef struct CAuthorization {

            CAuthorizationSchemes Schema;

            CString Username;
            CString Password;
            CString Session;

            CAuthorization(): Schema(asUnknown) {

            }

            explicit CAuthorization(const CString& String): CAuthorization() {
                Parse(String);
            }

            void Parse(const CString& String) {
                if (String.SubString(0, 5).Lower() == "basic") {
                    const CString LPassphrase(base64_decode(String.SubString(6)));

                    const size_t LPos = LPassphrase.Find(':');
                    if (LPos == CString::npos)
                        throw Delphi::Exception::Exception("Authorization error: Incorrect passphrase.");

                    Schema = asBasic;
                    Username = LPassphrase.SubString(0, LPos);
                    Password = LPassphrase.SubString(LPos + 1);

                    if (Username.IsEmpty() || Password.IsEmpty())
                        throw Delphi::Exception::Exception("Authorization error: Username and password has not be empty.");
                } else if (String.SubString(0, 7).Lower() == "session") {
                    Schema = asSession;
                    Session = String.SubString(8);
                    if (Session.Length() != 40)
                        throw Delphi::Exception::Exception("Authorization error: Incorrect session length.");
                } else {
                    throw Delphi::Exception::Exception("Authorization error: Unknown schema.");
                }
            }

            CAuthorization &operator << (const CString& String) {
                Parse(String);
                return *this;
            }

        } CAuthorization;

        //--------------------------------------------------------------------------------------------------------------

        //-- CWebService -----------------------------------------------------------------------------------------------

        //--------------------------------------------------------------------------------------------------------------

        class CWebService: public CApostolModule {
        private:

            int m_Version;

            CJobManager *m_Jobs;

            static void DebugRequest(CRequest *ARequest);
            static void DebugReply(CReply *AReply);
            static void DebugConnection(CHTTPServerConnection *AConnection);

            static CString QuoteJsonString(const CString &String);
            static void ExceptionToJson(int ErrorCode, const std::exception &AException, CString& Json);

            static void PQResultToJson(CPQResult *Result, CString& Json);
            static void QueryToJson(CPQPollQuery *Query, CString& Json);

            bool QueryStart(CHTTPServerConnection *AConnection, const CStringList& SQL);
            bool APIRun(CHTTPServerConnection *AConnection, const CString &Route, const CString &jsonString, const CAuthorization &Authorization);

        protected:

            void DoGet(CHTTPServerConnection *AConnection);
            void DoPost(CHTTPServerConnection *AConnection);

            static void DoWWW(CHTTPServerConnection *AConnection);

            void DoPostgresQueryExecuted(CPQPollQuery *APollQuery) override;
            void DoPostgresQueryException(CPQPollQuery *APollQuery, Delphi::Exception::Exception *AException) override;

        public:

            explicit CWebService(CModuleManager *AManager);

            ~CWebService() override;

            static class CWebService *CreateModule(CModuleManager *AManager) {
                return new CWebService(AManager);
            }

            void InitMethods() override;

            void BeforeExecute(Pointer Data) override;
            void AfterExecute(Pointer Data) override;

            void Heartbeat() override;
            void Execute(CHTTPServerConnection *AConnection) override;

            bool CheckUserAgent(const CString& Value) override;

        };

    }
}

using namespace Apostol::WebService;
}
#endif //APOSTOL_WEBSERVICE_HPP
