module Network.Mattermost.Proxy
  ( Scheme(..)
  , proxyForScheme
  )
where

import Control.Applicative ((<|>))
import Data.Char (toLower)
import Data.List (isPrefixOf)
import Network.URI (parseURI, uriRegName, uriPort, uriAuthority, uriScheme)
import System.Environment (getEnvironment)
import Text.Read (readMaybe)

data Scheme = HTTP | HTTPS
            deriving (Eq, Show)

newtype NormalizedEnv = NormalizedEnv [(String, String)]

proxyForScheme :: Scheme -> IO (Maybe (String, Int))
proxyForScheme s = do
    env <- getEnvironment
    let proxy = case s of
          HTTP -> httpProxy
          HTTPS -> httpsProxy
    return $ proxy $ normalizeEnv env

httpProxy :: NormalizedEnv -> Maybe (String, Int)
httpProxy env = socksProxyFor "HTTP_PROXY" env <|>
                socksProxyFor "ALL_PROXY" env

httpsProxy :: NormalizedEnv -> Maybe (String, Int)
httpsProxy env = socksProxyFor "HTTPS_PROXY" env <|>
                 socksProxyFor "ALL_PROXY" env

socksProxyFor :: String -> NormalizedEnv -> Maybe (String, Int)
socksProxyFor name env = do
    val <- envLookup name env
    uri <- parseURI val

    let scheme = uriScheme uri
        isSocks = "socks" `isPrefixOf` scheme
    if isSocks
       then do
           auth <- uriAuthority uri
           port <- readMaybe (drop 1 $ uriPort auth)
           return (uriRegName auth, port)
        else Nothing

normalizeEnv :: [(String, String)] -> NormalizedEnv
normalizeEnv env =
    let norm (k, v) = (normalizeVar k, v)
    in NormalizedEnv $ norm <$> env

normalizeVar :: String -> String
normalizeVar = (toLower <$>)

envLookup :: String -> NormalizedEnv -> Maybe String
envLookup v (NormalizedEnv env) = lookup (normalizeVar v) env