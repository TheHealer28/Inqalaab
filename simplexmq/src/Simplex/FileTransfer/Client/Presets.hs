{-# LANGUAGE OverloadedLists #-}
{-# LANGUAGE OverloadedStrings #-}

module Simplex.FileTransfer.Client.Presets where

import Data.List.NonEmpty (NonEmpty)
import Simplex.Messaging.Protocol (XFTPServerWithAuth)

defaultXFTPServers :: NonEmpty XFTPServerWithAuth
defaultXFTPServers =
  [ "xftp://RzgzPjyel91YLliscUGXCjReG1kYV_5_o0pvOfZA_4s=@xftp.suchkitalash.info:5233",
    "xftp://oOvy6k99LT5dySeIOmw5-G4FDZ5o3SSpVwm6YmyBsZI=@xftp1.inqalaab.chat",
    "xftp://Aik60WjmVFLWOK2dKYEjEbfdUWxuyUpAp-VO3FcOE5w=@xftp2.inqalaab.chat:5233",
    "xftp://rQDMhOx8wUv7O6J3vht2W3HMsUXbqv0HZPQb3Ce02ss=@xftp3.inqalaab.chat:5233"
  ]
