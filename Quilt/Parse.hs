{-# LANGUAGE FlexibleContexts #-}

module Quilt.Parse (
    parse,
) where

import Quilt.Value
import Quilt.Env
import Quilt.Eval

import Control.Monad.Except
import Control.Monad.State

import Debug.Trace

extractParsing :: Value -> [Value] -> Value -> Eval [Value]
extractParsing _ _ (ListVal l) = return l
extractParsing r args _ = throwError $ InvalidRule r args

evalRule :: Value -> [Value] -> Eval [Value]
evalRule r args = eval (FuncCall r args) >>= extractParsing r args

runRule :: Value -> String -> Value -> Eval [(Value, Env)]
runRule c s r = do
    traceShow ("trying", r) $ return ()
    startEnv <- getEnv
    ps <- evalRule r [StringVal s, c]
    endEnv <- getEnv
    putEnv startEnv
    return $ map (\v -> (v, endEnv)) ps

extractRules :: Value -> Eval [[Value]]
extractRules (ListVal [l@(ListVal _)]) = do
    rules <- extractRules l
    return $ [] : rules
extractRules (ListVal (x : rest)) = do
    l <- extractRules (ListVal rest)
    return $ case l of
        y:ys -> (x:y):ys
        [] -> [[x]]
extractRules (ListVal []) = return []
extractRules v = throwError $ InvalidType v

firstMatch :: [Eval [(Value, Env)]] -> Eval [(Value, Env)]
firstMatch (curr:rest) = do
    ps <- curr
    if null ps
    then firstMatch rest
    else return ps
firstMatch [] = return []

parse :: String -> [(Value, Value)] -> Eval [Value]
parse s l = do
    traceShow ("words left:", length $ words s, take 10 $ words s) $ return ()
    ends <- forM l $ \(rs, c) -> do
        rules <- extractRules rs
        firstMatch $ map (liftM concat . mapM (runRule c s)) rules
    case concat ends of
        [(v, env)] -> putEnv env >> return [v]
        [] -> return []
        e -> throwError $ AmbiguousParsing (map fst e)
