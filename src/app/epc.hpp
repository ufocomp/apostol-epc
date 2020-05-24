/*++

Program name:

  epc

Module Name:

  Epc.hpp

Notices:

  Apostol Electro

Author:

  Copyright (c) Prepodobny Alen

  mailto: alienufo@inbox.ru
  mailto: ufocomp@gmail.com

--*/

#ifndef APOSTOL_APOSTOL_HPP
#define APOSTOL_APOSTOL_HPP

#include "../../version.h"
//----------------------------------------------------------------------------------------------------------------------

#define APP_VERSION      AUTO_VERSION
#define APP_VER          APP_NAME "/" APP_VERSION
//----------------------------------------------------------------------------------------------------------------------

#include "Core.hpp"
#include "Modules.hpp"
//----------------------------------------------------------------------------------------------------------------------

extern "C++" {

namespace Apostol {

    namespace EPC {

        class CEPC: public CApplication {
        protected:

            void ParseCmdLine() override;
            void ShowVersionInfo() override;

        public:

            CEPC(int argc, char *const *argv): CApplication(argc, argv) {
                CreateModules(this);
            };

            ~CEPC() override = default;

            static class CEPC *Create(int argc, char *const *argv) {
                return new CEPC(argc, argv);
            };

            inline void Destroy() override { delete this; };

            void Run() override;

        };
    }
}

using namespace Apostol::EPC;
}

#endif //APOSTOL_APOSTOL_HPP

