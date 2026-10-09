{-# LANGUAGE OverloadedLists #-}
{-# LANGUAGE OverloadedStrings #-}

module Simplex.FileTransfer.Client.Presets where

import Data.List.NonEmpty (NonEmpty)
import Simplex.Messaging.Protocol (XFTPServerWithAuth)

defaultXFTPServers :: NonEmpty XFTPServerWithAuth
defaultXFTPServers =
  [ "xftp://RzgzPjyel91YLliscUGXCjReG1kYV_5_o0pvOfZA_4s=@xftp.suchkitalash.info:5233",
    "xftp://Rs0YhJBOdAE1dXruOTXIfltkta5CQax2ZRgEyXdTyog=@xftp1.inqalaab.chat:443",
    "xftp://Aik60WjmVFLWOK2dKYEjEbfdUWxuyUpAp-VO3FcOE5w=@xftp2.inqalaab.chat:5233",
    "xftp://rQDMhOx8wUv7O6J3vht2W3HMsUXbqv0HZPQb3Ce02ss=@xftp3.inqalaab.chat:5233",
    "xftp://_yliO3argaVEhPG4ajaynctMWHFelsvC_GwtP-h1Mnc=@xftp4.inqalaab.chat:443",
    "xftp://qcQ1fAdGPBFNgQq4FmN4Klqf1Sky68w06thBxNp-5TQ=@xftp5.inqalaab.chat:443",
    "xftp://-dvwQSUq1goxTbV-AzrIcvjJ5sk-69rtYK3fo88HkMw=@xftp6.inqalaab.chat:443"
  ]
