{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedLists #-}
{-# LANGUAGE OverloadedStrings #-}

module Inqalaab.Chat.Operators.Presets where

import Data.List.NonEmpty (NonEmpty)
import qualified Data.List.NonEmpty as L
import Inqalaab.Chat.Operators
import Simplex.Messaging.Agent.Env.SQLite (ServerRoles (..), allRoles)
import Simplex.Messaging.Agent.Store.Entity
import Simplex.Messaging.Protocol (ProtocolType (..), SMPServer)

operatorSimpleXChat :: NewServerOperator
operatorSimpleXChat =
  ServerOperator
    { operatorId = DBNewEntity,
      operatorTag = Just OTSimplex,
      tradeName = "Inqalaab",
      legalName = Just "Your Healing Artist Limited",
      serverDomains = ["suchkitalash.info", "inqalaab.chat"],
      conditionsAcceptance = CARequired Nothing,
      enabled = True,
      smpRoles = allRoles,
      xftpRoles = allRoles
    }

operatorFlux :: NewServerOperator
operatorFlux =
  ServerOperator
    { operatorId = DBNewEntity,
      operatorTag = Just OTFlux,
      tradeName = "Flux",
      legalName = Just "InFlux Technologies Limited",
      serverDomains = [],
      conditionsAcceptance = CARequired Nothing,
      enabled = False,
      smpRoles = ServerRoles {storage = False, proxy = True},
      xftpRoles = ServerRoles {storage = False, proxy = True}
    }

-- Inqalaab: 4 SMP + 4 XFTP self-hosted servers.
-- CRITICAL: Each (host, port) pair can only appear ONCE across ALL operator
-- server lists due to UNIQUE(user_id, host, port) on protocol_servers table.
-- The original SimpleX code had ~10 different SMP servers spread across
-- enabled/disabled/flux lists. We have 4 unique SMP servers — all go in
-- enabledInqalaabSMPServers. disabledInqalaabSMPServers and
-- fluxSMPServers_ must NOT duplicate any of these.

allPresetServers :: NonEmpty SMPServer
allPresetServers = enabledInqalaabSMPServers

inqalaabSMPServers :: [NewUserServer 'PSMP]
inqalaabSMPServers =
  map (presetServer' True) (L.toList enabledInqalaabSMPServers)

-- All 4 Inqalaab SMP servers (enabled)
enabledInqalaabSMPServers :: NonEmpty SMPServer
enabledInqalaabSMPServers =
  [ "smp://4CfWwei1oOFAhmfUkmpsrSRELYLCvKBPgQIJlOT5z8I=@smp.suchkitalash.info:5223",
    "smp://jKkKmm64Gf6jWa2unI5t0QudCoTZxxFp8o28fDZWZU4=@smp1.inqalaab.chat:5223",
    "smp://JfdjUvMRakyzH7yzucTLoxKsY-EfvA0bMTj7kZG3Szs=@smp2.inqalaab.chat",
    "smp://3XECaNOaqlLc_hPyrWSmw4rxrUGxALf5qQVqjaz-D-Y=@smp3.inqalaab.chat"
  ]

-- No disabled servers (would duplicate enabled list and violate UNIQUE constraint)
disabledInqalaabSMPServers :: NonEmpty SMPServer
disabledInqalaabSMPServers = enabledInqalaabSMPServers

-- No separate Flux SMP servers (all servers are under Inqalaab operator)
fluxSMPServers :: [NewUserServer 'PSMP]
fluxSMPServers = []

-- Required for type compatibility but not inserted into DB
fluxSMPServers_ :: NonEmpty SMPServer
fluxSMPServers_ = enabledInqalaabSMPServers

-- All 4 Inqalaab XFTP servers
fluxXFTPServers :: [NewUserServer 'PXFTP]
fluxXFTPServers =
  map
    (presetServer True)
    [ "xftp://RzgzPjyel91YLliscUGXCjReG1kYV_5_o0pvOfZA_4s=@xftp.suchkitalash.info:5233",
      "xftp://oOvy6k99LT5dySeIOmw5-G4FDZ5o3SSpVwm6YmyBsZI=@xftp1.inqalaab.chat",
      "xftp://Aik60WjmVFLWOK2dKYEjEbfdUWxuyUpAp-VO3FcOE5w=@xftp2.inqalaab.chat:5233",
      "xftp://rQDMhOx8wUv7O6J3vht2W3HMsUXbqv0HZPQb3Ce02ss=@xftp3.inqalaab.chat:5233"
    ]
