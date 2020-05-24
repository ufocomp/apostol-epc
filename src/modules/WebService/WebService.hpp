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
                if (String.IsEmpty())
                    throw Delphi::Exception::Exception("Authorization error: Data not found.");

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

            void InitMethods() override;

            static void QueryToJson(CPQPollQuery *Query, CString& Json);

            void APIRun(CHTTPServerConnection *AConnection, const CString &Route, const CString &jsonString, const CAuthorization &Authorization);

        protected:

            void DoObject(CHTTPServerConnection *AConnection, const CStringList& Routs);

            void DoAPI(CHTTPServerConnection *AConnection);

            void DoGet(CHTTPServerConnection *AConnection) override;
            void DoPost(CHTTPServerConnection *AConnection);

            void DoPostgresQueryExecuted(CPQPollQuery *APollQuery) override;
            void DoPostgresQueryException(CPQPollQuery *APollQuery, Delphi::Exception::Exception *AException) override;

        public:

            explicit CWebService(CModuleManager *AManager);

            ~CWebService() override = default;

            static class CWebService *CreateModule(CModuleManager *AManager) {
                return new CWebService(AManager);
            }

            bool CheckUserAgent(const CString& Value) override;

        };
    }
}

using namespace Apostol::WebService;
}
#endif //APOSTOL_WEBSERVICE_HPP
