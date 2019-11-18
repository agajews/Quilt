module Quilt.Builtins (
    builtins,
) where

import Quilt.Value
import Quilt.Eval

import Control.Monad.Except

builtins :: [(String, [Value] -> Eval Value)]
builtins = [("+", function intPlus),
            ("-", function intMinus)]

function :: ([Value] -> Eval Value) -> [Value] -> Eval Value
function f args = mapM eval args >>= f

intPlus :: [Value] -> Eval Value
intPlus [IntVal x, IntVal y] = return $ IntVal (x + y)
intPlus _ = throwError InvalidArguments

intMinus :: [Value] -> Eval Value
intMinus [IntVal x, IntVal y] = return $ IntVal (x - y)
intMinus _ = throwError InvalidArguments
