/*++

Program name:

  Apostol Web Service

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

#include "jwt.h"
//----------------------------------------------------------------------------------------------------------------------

#include <random>
#include <openssl/sha.h>
#include <openssl/hmac.h>
//----------------------------------------------------------------------------------------------------------------------

#define SHA256_DIGEST_LENGTH   32

extern "C++" {

namespace Apostol {

    namespace Workers {

        CString to_string(unsigned long Value) {
            TCHAR szString[_INT_T_LEN + 1] = {0};
            sprintf(szString, "%lu", Value);
            return CString(szString);
        }
        //--------------------------------------------------------------------------------------------------------------

        CString b2a_hex(const unsigned char *byte_arr, int size) {
            const static CString HexCodes = "0123456789abcdef";
            CString HexString;
            for ( int i = 0; i < size; ++i ) {
                unsigned char BinValue = byte_arr[i];
                HexString += HexCodes[(BinValue >> 4) & 0x0F];
                HexString += HexCodes[BinValue & 0x0F];
            }
            return HexString;
        }
        //--------------------------------------------------------------------------------------------------------------

        CString hmac_sha256(const CString &key, const CString &data) {
            unsigned char* digest;
            digest = HMAC(EVP_sha256(), key.data(), key.length(), (unsigned char *) data.data(), data.length(), nullptr, nullptr);
            return b2a_hex( digest, SHA256_DIGEST_LENGTH );
        }
        //--------------------------------------------------------------------------------------------------------------

        CString SHA1(const CString &data) {
            CString digest;
            digest.SetLength(SHA_DIGEST_LENGTH);
            ::SHA1((unsigned char *) data.data(), data.length(), (unsigned char *) digest.Data());
            return digest;
        }
        //--------------------------------------------------------------------------------------------------------------

        CDateTime StringToDate(const CString &Value) {
            return StrToDateTimeDef(Value.c_str(), 0, "%04d-%02d-%02d %02d:%02d:%02d");
        }
        //--------------------------------------------------------------------------------------------------------------

        CString DateToString(const CDateTime &Value) {
            TCHAR Buffer[20] = {0};
            DateTimeToStr(Value, Buffer, sizeof(Buffer));
            return Buffer;
        }
        //--------------------------------------------------------------------------------------------------------------

        CDateTime GetRandomDate(int a, int b, CDateTime Date) {
            std::random_device rd;
            std::mt19937 gen(rd());
            std::uniform_int_distribution<> time(a, b);
            CDateTime delta = time(gen);
            return Date + (CDateTime) (delta / 86400);
        }

        //--------------------------------------------------------------------------------------------------------------

        //-- CWebService -----------------------------------------------------------------------------------------------

        //--------------------------------------------------------------------------------------------------------------

        CWebService::CWebService(CModuleProcess *AProcess) : CApostolModule(AProcess, "web service") {
            m_Headers.Add("Authorization");
            m_Headers.Add("Session");
            m_Headers.Add("Nonce");
            m_Headers.Add("Signature");
            m_Headers.Add("Key");

            m_FixedDate = Now();

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

        void CWebService::PQResultToList(CPQResult *Result, CStringList &List) {
            for (int Row = 0; Row < Result->nTuples(); ++Row) {
                List.Add(Result->GetValue(Row, 0));
            }
        }
        //--------------------------------------------------------------------------------------------------------------

        void CWebService::ListToJson(const CStringList &List, CString &Json) {
            if (List.Count() > 1)
                Json = _T("[");

            for (int i = 0; i < List.Count(); ++i) {
                const auto& Line = List[i];
                if (!Line.IsEmpty()) {
                    if (i > 0)
                        Json += _T(",");
                    Json += Line;
                }
            }

            if (List.Count() > 1)
                Json += _T("]");
        }
        //--------------------------------------------------------------------------------------------------------------

        void CWebService::PQResultToJson(CPQResult *Result, CString &Json) {

            if (Result->nTuples() == 0) {
                Json = _T("{}");
                return;
            }

            if (Result->nTuples() > 1)
                Json = _T("[");

            for (int Row = 0; Row < Result->nTuples(); ++Row) {
                if (!Result->GetIsNull(Row, 0)) {
                    if (Row > 0)
                        Json += _T(",");
                    Json += Result->GetValue(Row, 0);
                }
            }

            if (Result->nTuples() > 1)
                Json += _T("]");
        }
        //--------------------------------------------------------------------------------------------------------------

        void CWebService::AfterQueryWS(CHTTPServerConnection *AConnection, const CString &Path, const CJSON &Payload) {

            auto lpSession = CSession::FindOfConnection(AConnection);

            auto SignIn = [lpSession](const CJSON &Payload) {
                if (Payload.HasOwnProperty(_T("error")))
                    return;

                const auto Result = Payload[_T("result")].AsBoolean();
                const auto& Message = Payload[_T("message")].AsString();

                if (!Result)
                    throw Delphi::Exception::EDBError(Message.c_str());

                const auto& Session = Payload[_T("session")].AsString();
                const auto& Secret = Payload[_T("secret")].AsString();

                lpSession->Session() = Session;
                lpSession->Secret() = Secret;
            };

            auto SignOut = [lpSession](const CJSON &Payload) {
                if (Payload.HasOwnProperty(_T("error")))
                    return;

                const auto Result = Payload[_T("result")].AsBoolean();
                const auto& Message = Payload[_T("message")].AsString();

                if (!Result)
                    throw Delphi::Exception::EDBError(Message.c_str());

                lpSession->Session().Clear();
                lpSession->Secret().Clear();
            };

            if (Path == _T("/sign/in")) {

                if (Payload.IsObject()) {
                    SignIn(Payload);
                } else if (Payload.IsArray()) {
                    for (int i = 0; i < Payload.Count(); i++) {
                        const auto& Value = Payload.Array()[i];
                        if (Value.IsObject()) {
                            SignIn(Value);
                        }
                    }
                }

            } else if (Path == _T("/sign/out")) {

                if (Payload.IsObject()) {
                    SignOut(Payload);
                } else if (Payload.IsArray()) {
                    for (int i = 0; i < Payload.Count(); i++) {
                        const auto& Value = Payload.Array()[i];
                        if (Value.IsObject()) {
                            SignOut(Value);
                        }
                    }
                }
            }
        }
        //--------------------------------------------------------------------------------------------------------------

        void CWebService::AfterQuery(CReply *AReply, const CString &Path, const CString &Content) {

            auto SignIn = [AReply](const CJSON &Payload) {
                if (Payload.HasOwnProperty(_T("error")))
                    return;

                const auto Result = Payload[_T("result")].AsBoolean();
                const auto& Message = Payload[_T("message")].AsString();

                if (Result) {
                    const auto &Session = Payload[_T("session")].AsString();
                    if (!Session.IsEmpty())
                        AReply->SetCookie(_T("AWS-Session"), Session.c_str(), _T("/"), 60 * 86400);

                    const auto &Key = Payload[_T("key")].AsString();
                    if (!Key.IsEmpty())
                        AReply->SetCookie(_T("API-Key"), Key.c_str(), _T("/api"), 60 * 86400);
                }
            };

            auto SignOut = [AReply](const CJSON &Payload) {
                if (Payload.HasOwnProperty(_T("error")))
                    return;

                const auto Result = Payload[_T("result")].AsBoolean();
                const auto& Message = Payload[_T("message")].AsString();

                AReply->SetCookie(_T("AWS-Session"), _T("null"), _T("/"), -1);
                AReply->SetCookie(_T("API-Key"), _T("null"), _T("/api"), -1);
            };

            auto Authenticate = [AReply](const CJSON &Payload) {
                if (Payload.HasOwnProperty(_T("error")))
                    return;

                const auto Result = Payload[_T("result")].AsBoolean();
                const auto& Message = Payload[_T("message")].AsString();

                if (Result) {
                    const auto &Key = Payload[_T("key")].AsString();
                    if (!Key.IsEmpty()) {
                        AReply->Headers.Values(_T("Key"), Key);
                        AReply->SetCookie(_T("API-Key"), Key.c_str(), _T("/api"), 0);
                    }
                }
            };

            if (Path == _T("/sign/in")) {

                const CJSON Payload(Content);

                if (Payload.IsObject()) {
                    SignIn(Payload);
                } else if (Payload.IsArray()) {
                    for (int i = 0; i < Payload.Count(); i++) {
                        const auto& Value = Payload.Array()[i];
                        if (Value.IsObject()) {
                            SignIn(Value);
                        }
                    }
                }

            } else if (Path == _T("/sign/out")) {

                const CJSON Payload(Content);

                if (Payload.IsObject()) {
                    SignOut(Payload);
                } else if (Payload.IsArray()) {
                    for (int i = 0; i < Payload.Count(); i++) {
                        const auto& Value = Payload.Array()[i];
                        if (Value.IsObject()) {
                            SignOut(Value);
                        }
                    }
                }

            } else if (Path == _T("/authenticate")) {

                const CJSON Payload(Content);

                if (Payload.IsObject()) {
                    Authenticate(Payload);
                } else if (Payload.IsArray()) {
                    for (int i = 0; i < Payload.Count(); i++) {
                        const auto& Value = Payload.Array()[i];
                        if (Value.IsObject()) {
                            Authenticate(Value);
                        }
                    }
                }
            }
        }
        //--------------------------------------------------------------------------------------------------------------

        void CWebService::DoPostgresQueryExecuted(CPQPollQuery *APollQuery) {
            clock_t start = clock();

            auto LResult = APollQuery->Results(0);

            if (LResult->ExecStatus() != PGRES_TUPLES_OK) {
                QueryException(APollQuery, Delphi::Exception::EDBError(LResult->GetErrorMessage()));
                return;
            }

            auto LConnection = dynamic_cast<CHTTPServerConnection *> (APollQuery->PollConnection());

            if (LConnection != nullptr) {

                if (LConnection->Protocol() == pWebSocket ) {

                    auto LWSRequest = LConnection->WSRequest();
                    auto LWSReply = LConnection->WSReply();

                    const CString LRequest(LWSRequest->Payload());

                    CWSMessage wsmRequest;
                    CWSProtocol::Request(LRequest, wsmRequest);

                    CWSMessage wsmResponse;
                    CWSProtocol::PrepareResponse(wsmRequest, wsmResponse);

                    try {
                        CString jsonString;
                        PQResultToJson(LResult, jsonString);

                        wsmResponse.Payload << jsonString;
                        AfterQueryWS(LConnection, wsmRequest.Action, wsmResponse.Payload);
                    } catch (Delphi::Exception::Exception &E) {
                        wsmResponse.MessageTypeId = mtCallError;
                        wsmResponse.ErrorCode = CReply::internal_server_error;
                        wsmResponse.ErrorMessage = E.what();

                        Log()->Error(APP_LOG_EMERG, 0, E.what());
                    }

                    CString LResponse;
                    CWSProtocol::Response(wsmResponse, LResponse);
#ifdef _DEBUG
                    DebugMessage("\n[%p] [%s:%d] [%d] [WebSocket] Response:\n%s\n", LConnection, LConnection->Socket()->Binding()->PeerIP(),
                                 LConnection->Socket()->Binding()->PeerPort(), LConnection->Socket()->Binding()->Handle(), LResponse.c_str());
#endif
                    LWSReply->SetPayload(LResponse);
                    LConnection->SendWebSocket(true);

                } else {

                    auto LReply = LConnection->Reply();

                    const auto& LGrandType = LConnection->Data()["grant_type"];
                    const auto& LPath = LConnection->Data()["path"];

                    CReply::CStatusType LStatus = CReply::internal_server_error;

                    try {
                        if (LGrandType == "client") {
                            CStringList List;
                            PQResultToList(LResult, List);

                            LStatus = CReply::no_content;
                            if (List.Count() != 0) {
                                LStatus = CReply::ok;

                                AfterQuery(LReply, _T("/authenticate"), List[0]);

                                List.Delete(0);
                                if (List.Count() == 0) {
                                    LReply->Content =_T("{}");
                                } else {
                                    ListToJson(List, LReply->Content);
                                    AfterQuery(LReply, LPath, LReply->Content);
                                }
                            }
                        } else {
                            PQResultToJson(LResult, LReply->Content);
                            AfterQuery(LReply, LPath, LReply->Content);
                            LStatus = CReply::ok;
                        }
                    } catch (Delphi::Exception::Exception &E) {
                        LReply->Content.Clear();
                        ExceptionToJson(0, E, LReply->Content);
                        Log()->Error(APP_LOG_EMERG, 0, E.what());
                    }

                    LConnection->SendReply(LStatus, nullptr, true);
                }

            } else {

                auto LJob = m_pJobs->FindJobByQuery(APollQuery);
                if (LJob == nullptr) {
                    Log()->Error(APP_LOG_EMERG, 0, _T("Job not found by Query."));
                    return;
                }

                const auto& LGrandType = LConnection->Data()["grant_type"];
                const auto& LPath = LJob->Data()["path"];

                auto LReply = &LJob->Reply();

                try {
                    if (LGrandType == "client") {
                        CStringList List;
                        PQResultToList(LResult, List);

                        if (List.Count() != 0) {
                            AfterQuery(LReply, _T("/authenticate"), List[0]);

                            List.Delete(0);
                            if (List.Count() == 0) {
                                LReply->Content =_T("{}");
                            } else {
                                ListToJson(List, LReply->Content);
                                AfterQuery(LReply, LPath, LReply->Content);
                            }
                        }
                    } else {
                        PQResultToJson(LResult, LReply->Content);
                        AfterQuery(LReply, LPath, LReply->Content);
                    }
                } catch (Delphi::Exception::Exception &E) {
                    LReply->Content.Clear();
                    ExceptionToJson(0, E, LReply->Content);
                    Log()->Error(APP_LOG_EMERG, 0, E.what());
                }
            }

            log_debug1(APP_LOG_DEBUG_CORE, Log(), 0, _T("Query executed runtime: %.2f ms."), (double) ((clock() - start) / (double) CLOCKS_PER_SEC * 1000));
        }
        //--------------------------------------------------------------------------------------------------------------

        void CWebService::QueryException(CPQPollQuery *APollQuery, const std::exception &e) {

            auto LConnection = dynamic_cast<CHTTPServerConnection *> (APollQuery->PollConnection());

            if (LConnection == nullptr) {
                auto LJob = m_pJobs->FindJobByQuery(APollQuery);
                if (LJob != nullptr) {
                    ExceptionToJson(0, e, LJob->Reply().Content);
                }
            } else if (LConnection->Protocol() == pWebSocket) {
                auto LWSRequest = LConnection->WSRequest();
                auto LWSReply = LConnection->WSReply();

                const CString LRequest(LWSRequest->Payload());

                CWSMessage wsmRequest;
                CWSProtocol::Request(LRequest, wsmRequest);

                CWSMessage wsmResponse;
                CString LResponse;

                CJSON LJson;

                CWSProtocol::PrepareResponse(wsmRequest, wsmResponse);

                wsmResponse.MessageTypeId = mtCallError;
                wsmResponse.ErrorCode = CReply::internal_server_error;
                wsmResponse.ErrorMessage = e.what();

                CWSProtocol::Response(wsmResponse, LResponse);
#ifdef _DEBUG
                DebugMessage("\n[%p] [%s:%d] [%d] [WebSocket] Response:\n%s\n", LConnection,
                             LConnection->Socket()->Binding()->PeerIP(),
                             LConnection->Socket()->Binding()->PeerPort(), LConnection->Socket()->Binding()->Handle(),
                             LResponse.c_str());
#endif
                LWSReply->SetPayload(LResponse);
                LConnection->SendWebSocket(true);
            } else {
                auto LReply = LConnection->Reply();

                CReply::CStatusType LStatus = CReply::internal_server_error;

                ExceptionToJson(0, e, LReply->Content);

                LConnection->SendReply(LStatus, nullptr, true);
            }

            Log()->Error(APP_LOG_EMERG, 0, e.what());
        }
        //--------------------------------------------------------------------------------------------------------------

        void CWebService::DoPostgresQueryException(CPQPollQuery *APollQuery, Delphi::Exception::Exception *AException) {
            QueryException(APollQuery, *AException);
        }
        //--------------------------------------------------------------------------------------------------------------

        CString CWebService::GetSession(CRequest *ARequest) {
            const auto& headerSession = ARequest->Headers.Values(_T("Session"));
            const auto& cookieSession = ARequest->Cookies.Values(_T("AWS-Session"));

            return headerSession.IsEmpty() ? cookieSession : headerSession;
        }
        //--------------------------------------------------------------------------------------------------------------

        int CWebService::CheckSession(CRequest *ARequest, const CString &Path, CString &Session) {

            if (Path.SubString(0, 6) == "/sign/")
                return -1;

            const auto& LSession = GetSession(ARequest);

            if (LSession.Length() != 40)
                return 0;

            Session = LSession;

            return 1;
        }
        //--------------------------------------------------------------------------------------------------------------

        CString CWebService::CreateToken(const CCleanToken& CleanToken) {
            const auto& AuthParams = Server().AuthParams();
            const auto& Default = AuthParams.Default().Value();

            auto token = jwt::create()
                    .set_issuer(Default.Issuer())
                    .set_audience(Default.Audience())
                    .set_issued_at(std::chrono::system_clock::now())
                    .set_expires_at(std::chrono::system_clock::now() + std::chrono::seconds{3600})
                    .sign(jwt::algorithm::hs256{std::string(Default.Secret())});

            return token;
        }
        //--------------------------------------------------------------------------------------------------------------

        CString CWebService::VerifyToken(const CString &Token) {

            const auto& GetSecret = [](const CAuthParam& Param) {
                const auto& Secret = Param.Secret();
                if (Secret.IsEmpty())
                    throw ExceptionFrm("Not found \"Secret\" for provider: %s",  Param.Provider.c_str());
                return Secret;
            };

            const auto& AuthParams = Server().AuthParams();

            auto decoded = jwt::decode(Token);

            const auto& aud = CString(decoded.get_audience());
            auto Index = OAuth2::Helper::IndexOfAudience(AuthParams, aud);
            if (Index == -1)
                throw jwt::token_verification_exception("Token doesn't contain the required audience");

            const auto& AuthParam = AuthParams[Index].Value();

            const auto& iss = CString(decoded.get_issuer());
            const CStringList& Issuers = AuthParam.GetIssuers();
            if (Issuers[iss].IsEmpty())
                throw jwt::token_verification_exception("Token doesn't contain the required issuer");

            const auto& alg = decoded.get_algorithm();
            const auto& ch = alg.substr(0, 2);

            if (ch == "HS") {
                const auto& Secret = GetSecret(AuthParam);
                if (alg == "HS256") {
                    auto verifier = jwt::verify()
                            .allow_algorithm(jwt::algorithm::hs256{Secret});
                    verifier.verify(decoded);

                    return Token; // if algorithm HS256
                } else if (alg == "HS384") {
                    auto verifier = jwt::verify()
                            .allow_algorithm(jwt::algorithm::hs384{Secret});
                    verifier.verify(decoded);
                } else if (alg == "HS512") {
                    auto verifier = jwt::verify()
                            .allow_algorithm(jwt::algorithm::hs512{Secret});
                    verifier.verify(decoded);
                }
            } else if (ch == "RS") {

                const auto& kid = decoded.get_key_id();
                const auto& key = OAuth2::Helper::GetPublicKey(AuthParams, kid);

                if (alg == "RS256") {
                    auto verifier = jwt::verify()
                            .allow_algorithm(jwt::algorithm::rs256{key});
                    verifier.verify(decoded);
                } else if (alg == "RS384") {
                    auto verifier = jwt::verify()
                            .allow_algorithm(jwt::algorithm::rs384{key});
                    verifier.verify(decoded);
                } else if (alg == "RS512") {
                    auto verifier = jwt::verify()
                            .allow_algorithm(jwt::algorithm::rs512{key});
                    verifier.verify(decoded);
                }
            } else if (ch == "ES") {

                const auto& kid = decoded.get_key_id();
                const auto& key = OAuth2::Helper::GetPublicKey(AuthParams, kid);

                if (alg == "ES256") {
                    auto verifier = jwt::verify()
                            .allow_algorithm(jwt::algorithm::es256{key});
                    verifier.verify(decoded);
                } else if (alg == "ES384") {
                    auto verifier = jwt::verify()
                            .allow_algorithm(jwt::algorithm::es384{key});
                    verifier.verify(decoded);
                } else if (alg == "ES512") {
                    auto verifier = jwt::verify()
                            .allow_algorithm(jwt::algorithm::es512{key});
                    verifier.verify(decoded);
                }
            } else if (ch == "PS") {

                const auto& kid = decoded.get_key_id();
                const auto& key = OAuth2::Helper::GetPublicKey(AuthParams, kid);

                if (alg == "PS256") {
                    auto verifier = jwt::verify()
                            .allow_algorithm(jwt::algorithm::ps256{key});
                    verifier.verify(decoded);
                } else if (alg == "PS384") {
                    auto verifier = jwt::verify()
                            .allow_algorithm(jwt::algorithm::ps384{key});
                    verifier.verify(decoded);
                } else if (alg == "PS512") {
                    auto verifier = jwt::verify()
                            .allow_algorithm(jwt::algorithm::ps512{key});
                    verifier.verify(decoded);
                }
            }

            const auto& Secret = GetSecret(AuthParams.Default().Value());
            const auto& Result = CCleanToken(R"({"alg":"HS256","typ":"JWT"})", decoded.get_payload(), true);

            return Result.Sign(jwt::algorithm::hs256{Secret});
        }
        //--------------------------------------------------------------------------------------------------------------

        void CWebService::CheckAuthorizationData(CRequest *ARequest, CAuthorization &Authorization) {
            const auto& LHeaders = ARequest->Headers;
            const auto& LCookies = ARequest->Cookies;

            const auto& LAuthorization = LHeaders.Values(_T("Authorization"));
            if (LAuthorization.IsEmpty()) {
                const auto &headerSession = LHeaders.Values(_T("Session"));
                const auto &headerKey = LHeaders.Values(_T("Key"));

                const auto &cookieSession = LCookies.Values(_T("AWS-Session"));
                const auto &cookieKey = LCookies.Values(_T("API-Key"));

                Authorization.Username = headerSession.IsEmpty() ? cookieSession : headerSession;
                Authorization.Password = headerKey.IsEmpty() ? cookieKey : headerKey;

                if (Authorization.Username.IsEmpty() || Authorization.Password.IsEmpty())
                    throw CAuthorizationError("Access Denied.");

                Authorization.Schema = CAuthorization::asBasic;
                Authorization.GrantType = CAuthorization::agtClient;
            } else {
                Authorization << LAuthorization;
            }
        }
        //--------------------------------------------------------------------------------------------------------------

        bool CWebService::CheckAuthorization(CHTTPServerConnection *AConnection, CAuthorization &Authorization) {

            auto LRequest = AConnection->Request();
            auto LReply = AConnection->Reply();

            try {
                CheckAuthorizationData(LRequest, Authorization);
                if (Authorization.Schema == CAuthorization::asBearer) {
                    Authorization.Token = VerifyToken(Authorization.Token);
                }
                return true;
            } catch (jwt::token_expired_exception &e) {
                ExceptionToJson(CReply::forbidden, e, LReply->Content);
                CReply::GetReply(LReply, CReply::forbidden);
                CReply::AddUnauthorized(LReply, true, "invalid_token", e.what());
            } catch (jwt::token_verification_exception &e) {
                ExceptionToJson(CReply::unauthorized, e, LReply->Content);
                CReply::GetReply(LReply, CReply::unauthorized);
                CReply::AddUnauthorized(LReply, true, "invalid_token", e.what());
            } catch (CAuthorizationError &e) {
                ExceptionToJson(CReply::unauthorized, e, LReply->Content);
                CReply::GetReply(LReply, CReply::unauthorized);
                CReply::AddUnauthorized(LReply, Authorization.Schema == CAuthorization::asBearer, "unauthorized_client", e.what());
            } catch (std::exception &e) {
                ExceptionToJson(CReply::bad_request, e, LReply->Content);
                CReply::GetReply(LReply, CReply::bad_request);
                CReply::AddUnauthorized(LReply, Authorization.Schema == CAuthorization::asBearer, "invalid_request", e.what());
            }

            return false;
        }
        //--------------------------------------------------------------------------------------------------------------

        void CWebService::LoadProviders() {
            const CString pathCerts = Config()->Prefix() + _T("certs/");
            const CString lockFile = pathCerts + "lock";
            if (!FileExists(lockFile.c_str())) {
                CFile Lock(lockFile.c_str(), FILE_CREATE_OR_OPEN);
                Lock.Open();
                auto& AuthParams = Server().AuthParams();
                for (int i = 0; i < AuthParams.Count(); i++) {
                    auto &Param = AuthParams[i].Value();
                    if (FileExists(CString(pathCerts + Param.Provider).c_str())) {
                        Param.Keys.Clear();
                        Param.Keys.LoadFromFile(CString(pathCerts + Param.Provider).c_str());
                    }
                }
                Lock.Close(true);
                if (unlink(lockFile.c_str()) == FILE_ERROR) {
                    Log()->Error(APP_LOG_ALERT, errno, _T("Could not delete file: \"%s\" error: "), lockFile.c_str());
                }
            } else {
                m_FixedDate = Now() + (CDateTime) 1 / 86400; // 1 sec
            }
        }
        //--------------------------------------------------------------------------------------------------------------

        bool CWebService::SignUp(CHTTPServerConnection *AConnection, const CString &Payload) {

            auto OnExecuted = [this, AConnection](CPQPollQuery *APollQuery) {

                auto LReply = AConnection->Reply();
                auto LResult = APollQuery->Results(0);

                CReply::CStatusType LStatus = CReply::internal_server_error;

                try {
                    if (LResult->ExecStatus() != PGRES_TUPLES_OK)
                        throw Delphi::Exception::EDBError(LResult->GetErrorMessage());

                    PQResultToJson(LResult, LReply->Content);
                    LStatus = CReply::ok;
                } catch (Delphi::Exception::Exception &E) {
                    LReply->Content.Clear();
                    ExceptionToJson(0, E, LReply->Content);
                    Log()->Error(APP_LOG_EMERG, 0, E.what());
                }

                AConnection->SendReply(LStatus, nullptr, true);
            };

            auto OnException = [this, AConnection](CPQPollQuery *APollQuery, Delphi::Exception::Exception *AException) {

                Log()->Error(APP_LOG_EMERG, 0, AException->what());
                AConnection->SendStockReply(CReply::internal_server_error, true);

            };

            CStringList SQL;

            SQL.Add(CString().Format("SELECT * FROM daemon.SignUp('admin', %s, '%s'::jsonb);",
                                     m_Password.c_str(),
                                     Payload.IsEmpty() ? "{}" : Payload.c_str()
            ));

            return ExecSQL(SQL, AConnection, OnExecuted, OnException);
        }
        //--------------------------------------------------------------------------------------------------------------

        bool CWebService::SignIn(CHTTPServerConnection *AConnection, const CString &Payload, const CString &Agent,
                                 const CString &Host) {

            auto OnExecuted = [this, AConnection](CPQPollQuery *APollQuery) {

                auto LReply = AConnection->Reply();
                auto LResult = APollQuery->Results(0);

                CReply::CStatusType LStatus = CReply::internal_server_error;

                try {
                    if (LResult->ExecStatus() != PGRES_TUPLES_OK)
                        throw Delphi::Exception::EDBError(LResult->GetErrorMessage());

                    PQResultToJson(LResult, LReply->Content);
                    AfterQuery(LReply, "/sign/in", LReply->Content);
                    LStatus = CReply::ok;
                } catch (Delphi::Exception::Exception &E) {
                    LReply->Content.Clear();
                    ExceptionToJson(0, E, LReply->Content);
                    Log()->Error(APP_LOG_EMERG, 0, E.what());
                }

                AConnection->SendReply(LStatus, nullptr, true);
            };

            auto OnException = [this, AConnection](CPQPollQuery *APollQuery, Delphi::Exception::Exception *AException) {

                Log()->Error(APP_LOG_EMERG, 0, AException->what());
                AConnection->SendStockReply(CReply::internal_server_error, true);

            };

            CStringList SQL;

            SQL.Add(CString().Format("SELECT * FROM daemon.SignIn('%s'::jsonb, %s, %s);",
                                     Payload.IsEmpty() ? "{}" : Payload.c_str(),
                                     PQQuoteLiteral(Agent).c_str(),
                                     PQQuoteLiteral(Host).c_str()
            ));

            return ExecSQL(SQL, AConnection, OnExecuted, OnException);
        }
        //--------------------------------------------------------------------------------------------------------------

        bool CWebService::Authorize(CHTTPServerConnection *AConnection, const CString &Session, const CString &Path) {

            auto OnExecuted = [this, AConnection](CPQPollQuery *APollQuery) {

                auto LReply = AConnection->Reply();
                const auto& LSession = AConnection->Data()["session"];
                const auto& LPath = AConnection->Data()["path"];

                CPQResult *Result;
                CStringList SQL;

                try {
                    for (int I = 0; I < APollQuery->Count(); I++) {
                        Result = APollQuery->Results(I);

                        if (Result->ExecStatus() != PGRES_TUPLES_OK)
                            throw Delphi::Exception::EDBError(Result->GetErrorMessage());

                        if (Result->nFields() != 2)
                            throw Delphi::Exception::EDBError(_T("Invalid fields count."));

                        if (!Result->GetIsNull(0, 0)) {
                            if (SameText(Result->GetValue(0, 0), _T("t"))) {
                                if (!LPath.IsEmpty()) {
                                    SendResource(AConnection, LPath, _T("text/html"), true);
                                    return;
                                }
                            } else {
                                LReply->SetCookie(_T("API-Key"), _T("null"), _T("/api"), -1);
                                LReply->SetCookie(_T("AWS-Session"), _T("null"), _T("/"), -1);
                                if (!Result->GetIsNull(0, 1))
                                    Log()->Error(APP_LOG_INFO, 0, Result->GetValue(0, 1));
                            }
                        }
                    }
                } catch (std::exception &e) {
                    Log()->Error(APP_LOG_EMERG, 0, e.what());
                }

                Redirect(AConnection, _T("/sign/"),true);
            };

            auto OnException = [this, AConnection](CPQPollQuery *APollQuery, Delphi::Exception::Exception *AException) {

                Log()->Error(APP_LOG_EMERG, 0, AException->what());
                AConnection->SendStockReply(CReply::internal_server_error, true);

            };

            CStringList SQL;

            SQL.Add(CString().Format("SELECT * FROM daemon.Authorize('%s');", Session.c_str()));

            AConnection->Data().Values("session", Session);
            AConnection->Data().Values("path", Path);

            return ExecSQL(SQL, nullptr, OnExecuted, OnException);
        }
        //--------------------------------------------------------------------------------------------------------------

        void CWebService::AuthFetch(CHTTPServerConnection *AConnection, const CAuthorization &Authorization,
                const CString &Path, const CString &Payload, const CString &Agent, const CString &Host) {

            CStringList SQL;

            if (Authorization.Schema == CAuthorization::asBasic) {
                SQL.Add(CString().Format("SELECT * FROM daemon.%s(%s, %s, %s, '%s'::jsonb, %s, %s);",
                                         Authorization.GrantType == CAuthorization::agtOwner ? "Fetch" : "AuthFetch",
                                         PQQuoteLiteral(Authorization.Username).c_str(),
                                         PQQuoteLiteral(Authorization.Password).c_str(),
                                         PQQuoteLiteral(Path).c_str(),
                                         Payload.IsEmpty() ? "{}" : Payload.c_str(),
                                         PQQuoteLiteral(Agent).c_str(),
                                         PQQuoteLiteral(Host).c_str()
                ));

                if (Authorization.GrantType == CAuthorization::agtOwner)
                    AConnection->Data().Values("grant_type", "owner");
                else
                    AConnection->Data().Values("grant_type", "client");

            } else if (Authorization.Schema == CAuthorization::asBearer) {
                SQL.Add(CString().Format("SELECT * FROM daemon.TokenFetch(%s, '%s', %s, '%s'::jsonb, %s, %s);",
                                         m_Password.c_str(),
                                         Authorization.Token.c_str(),
                                         PQQuoteLiteral(Path).c_str(),
                                         Payload.IsEmpty() ? "{}" : Payload.c_str(),
                                         PQQuoteLiteral(Agent).c_str(),
                                         PQQuoteLiteral(Host).c_str()
                ));

                if (Authorization.TokenType == CAuthorization::attAccess)
                    AConnection->Data().Values("token_type", "access");
                else
                    AConnection->Data().Values("token_type", "refresh");

            } else {
                AConnection->SendStockReply(CReply::bad_request);
                return;
            }

            AConnection->Data().Values("signature", "false");
            AConnection->Data().Values("path", Path);

            if (!StartQuery(AConnection, SQL)) {
                AConnection->SendStockReply(CReply::service_unavailable);
            }
        }
        //--------------------------------------------------------------------------------------------------------------

        void CWebService::SignFetch(CHTTPServerConnection *AConnection, const CString &Path, const CString &Payload,
                const CString &Session, const CString &Nonce, const CString &Signature, const CString &Agent,
                const CString &Host, long int ReceiveWindow) {

            CStringList SQL;
            SQL.Add(CString());

            if (Path == "/sign/in") {
                SignIn(AConnection, Payload, Agent, Host);
                return;
            } else if (Path == "/sign/up") {
                SignUp(AConnection, Payload);
                return;
            } else {
                SQL.Last().Format("SELECT * FROM daemon.SignFetch(%s, '%s'::json, %s, %s, %s, %s, %s, INTERVAL '%d milliseconds');",
                                  PQQuoteLiteral(Path).c_str(),
                                  Payload.IsEmpty() ? "{}" : Payload.c_str(),
                                  PQQuoteLiteral(Session).c_str(),
                                  PQQuoteLiteral(Nonce).c_str(),
                                  PQQuoteLiteral(Signature).c_str(),
                                  PQQuoteLiteral(Agent).c_str(),
                                  PQQuoteLiteral(Host).c_str(),
                                  ReceiveWindow
                );
            }

            AConnection->Data().Values("signature", "true");
            AConnection->Data().Values("path", Path);

            if (!StartQuery(AConnection, SQL)) {
                AConnection->SendStockReply(CReply::service_unavailable);
            }
        }
        //--------------------------------------------------------------------------------------------------------------

        void CWebService::DoSessionDisconnected(CObject *Sender) {
            auto LConnection = dynamic_cast<CHTTPServerConnection *>(Sender);
            if (LConnection != nullptr) {
                auto LSession = m_SessionManager.FindByConnection(LConnection);
                if (LSession != nullptr) {
                    Log()->Message(_T("[%s:%d] WebSocket Session %s closed connection."), LConnection->Socket()->Binding()->PeerIP(),
                                   LConnection->Socket()->Binding()->PeerPort(),
                                   LSession->Identity().IsEmpty() ? "(empty)" : LSession->Identity().c_str());
                    delete LSession;
                } else {
                    Log()->Message(_T("[%s:%d] WebSocket Session closed connection."), LConnection->Socket()->Binding()->PeerIP(),
                                   LConnection->Socket()->Binding()->PeerPort());
                }
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

            } else if (LCommand == "client" || LCommand == "contract" || LCommand == "address") {
                LPath = "/";
                LPath += LCommand;
                CheckParams(LRequest->Params, LAction, LPath, Json);
            } else {
                AConnection->SendStockReply(CReply::not_found);
                return;
            }

            try {
                CAuthorization LAuthorization;
                if (!CheckAuthorization(AConnection, LAuthorization)) {
                    AConnection->SendReply();
                    return;
                }

                const auto &LAgent = GetUserAgent(AConnection);
                const auto &LHost = GetHost(AConnection);

                AuthFetch(AConnection, LAuthorization, LPath, Json.ToString(), LAgent, LHost);
            } catch (std::exception &e) {
                AConnection->CloseConnection(true);
                AConnection->SendStockReply(CReply::bad_request);
                Log()->Error(APP_LOG_EMERG, 0, e.what());
            }
        }
        //--------------------------------------------------------------------------------------------------------------

        void CWebService::DoOAuth2(CHTTPServerConnection *AConnection) {

            auto AddParam = [AConnection](const CJSONMember &Item, TCHAR Separator = '&') {

                const auto& Key = Item.String();
                const auto& Value = Item.Value().AsString();

                if (Value.IsEmpty())
                    throw ExceptionFrm(_T("OAuth2: Parameter \"%s\" is empty."), Key.c_str());

                CString Result;

                Result << Separator;
                Result << Item.String();
                Result << _T("=");

                if (Key == _T("redirect_uri") && Value.front() == '/') {
                    const auto& Origin = GetOrigin(AConnection);
                    Result << CHTTPServer::URLEncode(Origin + Value);
                } else {
                    Result << CHTTPServer::URLEncode(Value);
                }

                return Result;
            };

            auto LRequest = AConnection->Request();
            auto LReply = AConnection->Reply();

            LReply->ContentType = CReply::html;

            CStringList LRouts;
            SplitColumns(LRequest->Location.pathname, LRouts, '/');

            if (LRouts.Count() < 2) {
                AConnection->SendStockReply(CReply::not_found);
                return;
            }

            CString Location;

            const auto& Provider = LRouts[1];

            if (LRouts.Count() == 2) {

                const auto& AuthParams = Server().AuthParams();
                const auto& AuthParam = AuthParams[Provider].Value();

                const auto& AuthURI = AuthParam.AuthURI();
                const auto& ClientId = AuthParam.Audience();

                CJSON jsonParams;
                if (LRequest->Content.IsEmpty()) {
                    for (int i = 0; i < LRequest->Params.Count(); ++i) {
                        jsonParams.Object().AddPair(LRequest->Params.Names(i), LRequest->Params.ValueFromIndex(i));
                    }
                } else {
                    ContentToJson(LRequest, jsonParams);
                }

                const auto& Params = jsonParams.Object();

                Location = AuthURI;
                Location += AddParam(CJSONMember("client_id", ClientId), '?');

                for (int i = 0; i < Params.Count(); i++)
                    Location += AddParam(Params.Members(i), '&');

            } else {
                const auto& Action = LRouts[2];

                if (Action == "code") {

                } else if (Action == "callback") {

                }

                DebugMessage("Callback (href): %s\n", LRequest->Location.href().c_str());
                Location = "/";
            }

            DebugMessage("Location: %s\n", Location.c_str());
            Redirect(AConnection, Location);
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

        void CWebService::DoWSSession(CHTTPServerConnection *AConnection) {

            auto LRequest = AConnection->Request();
            auto LReply = AConnection->Reply();

            LReply->ContentType = CReply::html;

            CStringList LPath;
            SplitColumns(LRequest->Location.pathname, LPath, '/');

            if (LPath.Count() < 2) {
                AConnection->SendStockReply(CReply::not_found);
                return;
            }

            const auto& LAuthorization = LRequest->Headers.Values(_T("Authorization"));

            const auto& LSecWebSocketKey = LRequest->Headers.Values(_T("Sec-WebSocket-Key"));
            if (LSecWebSocketKey.IsEmpty()) {
                AConnection->SendStockReply(CReply::bad_request, true);
                return;
            }

            const auto& LIdentity = LPath[1];
            const auto& LSecWebSocketProtocol = LRequest->Headers.Values(_T("Sec-WebSocket-Protocol"));

            const CString LAccept(SHA1(LSecWebSocketKey + _T("258EAFA5-E914-47DA-95CA-C5AB0DC85B11")));
            const CString LProtocol(LSecWebSocketProtocol.IsEmpty() ? "" : LSecWebSocketProtocol.SubString(0, LSecWebSocketProtocol.Find(',')));

            AConnection->SwitchingProtocols(LAccept, LProtocol);

            auto lpSession = m_SessionManager.FindByIdentity(LIdentity);
            if (lpSession == nullptr) {
                lpSession = m_SessionManager.Add(AConnection);

                lpSession->Identity() = LIdentity;
                lpSession->IP() = GetHost(AConnection);
                lpSession->Agent() = GetUserAgent(AConnection);

                if (LAuthorization.IsEmpty())
                    lpSession->Authorization() << LAuthorization;

#if defined(_GLIBCXX_RELEASE) && (_GLIBCXX_RELEASE >= 9)
                AConnection->OnDisconnected([this](auto && Sender) { DoSessionDisconnected(Sender); });
#else
                AConnection->OnDisconnected(std::bind(&CWebService::DoSessionDisconnected, this, _1));
#endif
            } else {
                lpSession->SwitchConnection(AConnection);
                lpSession->IP() = GetHost(AConnection);
                lpSession->Agent() = GetUserAgent(AConnection);
            }
        }
        //--------------------------------------------------------------------------------------------------------------

        void CWebService::DoWebSocket(CHTTPServerConnection *AConnection) {
            auto LWSRequest = AConnection->WSRequest();
            auto LWSReply = AConnection->WSReply();

            const CString LRequest(LWSRequest->Payload());
#ifdef _DEBUG
            DebugMessage(_T("\n[%p] [%s:%d] [%d] [WebSocket] Request:\n%s\n"), AConnection, AConnection->Socket()->Binding()->PeerIP(),
                         AConnection->Socket()->Binding()->PeerPort(), AConnection->Socket()->Binding()->Handle(), LRequest.c_str());
#endif
            try {
                auto lpSession = CSession::FindOfConnection(AConnection);

                CWSMessage wsmRequest;
                CWSMessage wsmResponse;

                try {
                    CString sigData;

                    CWSProtocol::Request(LRequest, wsmRequest);

                    if (wsmRequest.MessageTypeId == mtOpen) {
                        if (wsmRequest.Payload.ValueType() == jvtObject) {
                            wsmRequest.Action = _T("/authorize");

                            lpSession->Session() = wsmRequest.Payload[_T("session")].AsString();
                            lpSession->Secret() = wsmRequest.Payload[_T("secret")].AsString();

                            if (lpSession->Session().IsEmpty() || lpSession->Secret().IsEmpty())
                                throw Delphi::Exception::Exception(_T("Session or secret cannot be empty."));

                            wsmRequest.Payload -= _T("secret");
                        } else {
                            if (lpSession->Authorization().Schema != CAuthorization::asBasic)
                                throw Delphi::Exception::Exception(_T("No authorization data."));

                            wsmRequest.Action = _T("/sign/in");

                            wsmRequest.Payload.Object().AddPair(_T("username"), lpSession->Authorization().Username);
                            wsmRequest.Payload.Object().AddPair(_T("password"), lpSession->Authorization().Password);
                        }

                        wsmRequest.MessageTypeId = mtCall;
                    } else if (wsmRequest.MessageTypeId == mtClose) {
                        wsmRequest.Action = _T("/sign/out");
                        wsmRequest.MessageTypeId = mtCall;
                    }

                    const auto& LPayload = wsmRequest.Payload.ToString();
                    const auto& LNonce = to_string(MsEpoch() * 1000);

                    if (wsmRequest.MessageTypeId == mtCall) {

                        sigData = wsmRequest.Action;
                        sigData << LNonce;
                        sigData << (LPayload.IsEmpty() ? _T("null") : LPayload);

                        const auto& LSignature = lpSession->Secret().IsEmpty() ? _T("") : hmac_sha256(lpSession->Secret(), sigData);

                        SignFetch(AConnection, wsmRequest.Action, LPayload, lpSession->Session(), LNonce, LSignature,
                                  lpSession->Agent(), lpSession->IP());
                    } else {
                        // Ответ от устройства отправим в обработчик
                        auto LHandler = lpSession->Messages()->FindMessageById(wsmRequest.UniqueId);
                        if (Assigned(LHandler)) {
                            LHandler->Handler(AConnection);
                        }
                    }
                } catch (std::exception &e) {
                    CWSProtocol::PrepareResponse(wsmRequest, wsmResponse);

                    wsmResponse.MessageTypeId = mtCallError;
                    wsmResponse.ErrorCode = CReply::bad_request;
                    wsmResponse.ErrorMessage = e.what();

                    CString LResponse;
                    CWSProtocol::Response(wsmResponse, LResponse);

                    LWSReply->SetPayload(LResponse);
                    AConnection->SendWebSocket();

                    Log()->Error(APP_LOG_NOTICE, 0, e.what());
                }
            } catch (std::exception &e) {
                AConnection->SendWebSocketClose();
                AConnection->CloseConnection(true);

                Log()->Error(APP_LOG_EMERG, 0, e.what());
            }
        }
        //--------------------------------------------------------------------------------------------------------------

        void CWebService::DoGet(CHTTPServerConnection *AConnection) {
            auto LRequest = AConnection->Request();

            CString LPath(LRequest->Location.pathname);

            // Request path must be absolute and not contain "..".
            if (LPath.empty() || LPath.front() != '/' || LPath.find(_T("..")) != CString::npos) {
                AConnection->SendStockReply(CReply::bad_request);
                return;
            }

            if (LPath.SubString(0, 9) == _T("/session/")) {
                DoWSSession(AConnection);
                return;
            }

            if (LPath.SubString(0, 5) == _T("/api/")) {
                DoAPI(AConnection);
                return;
            }

            if (LPath.SubString(0, 8) == _T("/oauth2/")) {
                DoOAuth2(AConnection);
                return;
            }

            // If path ends in slash.
            if (LPath.back() == '/') {
                LPath += _T("index.html");
            }

            TCHAR szFileExt[PATH_MAX] = {0};
            auto fileExt = ExtractFileExt(szFileExt, LPath.c_str());

            if (SameText(fileExt, _T(".html")) || SameText(fileExt, _T(".htm"))) {
                CString LSession;
                const auto auth = CheckSession(LRequest, LPath, LSession);
                if (auth == 1) {
                    if (!Authorize(AConnection, LSession, LPath))
                        AConnection->SendStockReply(CReply::service_unavailable);
                    return;
                } else if (auth == 0) {
                    LPath = _T("/sign/index.html");
                } else if (auth == -1) {
                    const auto& Session = GetSession(LRequest);
                    if (Session.Length() == 40) {
                        Redirect(AConnection, _T("/"));
                    }
                }
            }

            SendResource(AConnection, LPath, Mapping::ExtToType(fileExt));
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

            const auto& LContentType = LRequest->Headers.Values(_T("Content-Type")).Lower();
            const auto contentJson = (LContentType.Find(_T("application/json")) != CString::npos);

            CJSON Json;
            if (!contentJson) {
                ContentToJson(LRequest, Json);
            }

            const auto& LAgent = GetUserAgent(AConnection);
            const auto& LHost = GetHost(AConnection);
            const auto& LPayload = contentJson ? LRequest->Content : Json.ToString();
            const auto& LSignature = LRequest->Headers.Values(_T("Signature"));

            try {
                if (LSignature.IsEmpty()) {

                    if (LPath == "/sign/in") {
                        SignIn(AConnection, LPayload, LAgent, LHost);
                        return;
                    } else if (LPath == "/sign/up") {
                        SignUp(AConnection, LPayload);
                        return;
                    } else {

                        CAuthorization LAuthorization;
                        if (!CheckAuthorization(AConnection, LAuthorization)) {
                            AConnection->SendReply();
                            return;
                        }

                        AuthFetch(AConnection, LAuthorization, LPath, LPayload, LAgent, LHost);
                    }
                } else {
                    const auto& LSession = GetSession(LRequest);
                    const auto& LNonce = LRequest->Headers.Values(_T("Nonce"));

                    long int LReceiveWindow = 5000;
                    const auto& receiveWindow = LRequest->Params[_T("receive_window")];
                    if (!receiveWindow.IsEmpty())
                        LReceiveWindow = StrToIntDef(receiveWindow.c_str(), LReceiveWindow);

                    SignFetch(AConnection, LPath, LPayload, LSession, LNonce, LSignature, LAgent, LHost, LReceiveWindow);
                }
            } catch (Delphi::Exception::Exception &E) {
                ExceptionToJson(0, E, LReply->Content);
                AConnection->SendReply(CReply::bad_request);
                Log()->Error(APP_LOG_EMERG, 0, E.what());
            }
        }
        //--------------------------------------------------------------------------------------------------------------

        void CWebService::BeforeExecute(Pointer Data) {
            CApostolModule::BeforeExecute(Data);

            if (m_Password.IsEmpty()) {
                const auto& connInfo = Config()->PostgresConnInfo();
                m_Password = PQQuoteLiteral(connInfo["password"]);
            }
        }
        //--------------------------------------------------------------------------------------------------------------

        void CWebService::Heartbeat() {
            auto now = Now();

            if ((now >= m_FixedDate)) {
                m_FixedDate = now + (CDateTime) 30 * 60 / 86400; // 30 min
                LoadProviders();
            }
        }
        //--------------------------------------------------------------------------------------------------------------

        void CWebService::Execute(CHTTPServerConnection *AConnection) {
            switch (AConnection->Protocol()) {
                case pHTTP:
                    CApostolModule::Execute(AConnection);
                    break;
                case pWebSocket:
                    DoWebSocket(AConnection);
                    break;
            }
        }
        //--------------------------------------------------------------------------------------------------------------

        bool CWebService::IsEnabled() {
            if (m_ModuleStatus == msUnknown)
                m_ModuleStatus = msEnabled;
            return m_ModuleStatus == msEnabled;
        }
        //--------------------------------------------------------------------------------------------------------------

        bool CWebService::CheckUserAgent(const CString &Value) {
            return IsEnabled();
        }

    }
}
}