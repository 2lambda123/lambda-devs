{-
Copyright (c) 2013, Markus Barenhoff <alios@alios.org>
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the <organization> nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

-}

{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeFamilies #-}

module Data.DEVS.Simulation.Types
    ( SimPorts
    , ProcessorConstructor
    , Processor (..)
    , SimulatorMsg (..)
    , TransportMsg (..)
    ) where


import Data.Typeable (Typeable)
import Data.Data (Data)
import Data.Binary
import Control.Distributed.Process
import Data.DEVS.Devs


-- | a touple of 'SendPort' used by 'Processor' for exchange of 'SimulatorMsg' and 'TransportMsg'
type SimPorts m = (SendPort SimulatorMsg, SendPort (TransportMsg m))


-- | type of a processor constructor 
type ProcessorConstructor m = 
    SimPorts m -- ^ 'SimPorts' for processor output
    -> m -- ^ the model run by the processor
    -> Process (SimPorts m) -- ^ returns 'SimPorts' for processor input

-- | a processor runs a model during simulation
class Processor p m where
    data ProcessorState p m :: * 
    mkProcessor :: p -> ProcessorConstructor m -- ^ a constructor
    proc_s0 :: p -> ProcessorState p m -- ^ the initial state 

-- | messages used by processors for syncronization
data SimulatorMsg 
    = MsgStar T
    | MsgAt T 
    | MsgDone T
      deriving (Typeable, Data)

-- | messages used by processor for event transportation
data TransportMsg m 
    = MsgY T (Y m)
    | MsgQ T (X m)
      deriving (Typeable)


--- 
--- Instances
---

instance Binary SimulatorMsg where
    put m = do
      put (0x01 :: Word8)
      case m of
        (MsgStar t) -> do put (0x01 :: Word8) ; put t
        (MsgAt t)   -> do put (0x02 :: Word8) ; put t
        (MsgDone t) -> do put (0x03 :: Word8) ; put t
    get = do
      b1 <- getWord8
      b2 <- getWord8
      t <- get
      if (b1 == 0x01) 
      then case b2 of
             0x01 -> return $ MsgStar t 
             0x02 -> return $ MsgAt t
             0x03 -> return $ MsgDone t
             _    -> fail $ "get SimulatorMsg : unknown msg code " ++ show b2
      else fail $ "parseError SimulatorMsg: expected 0x01, got " ++ show b1

instance (DEVS m) => Binary (TransportMsg m) where
    put m = do
      put (0x02 :: Word8)
      case m of
        (MsgY t y) -> do put (0x01 :: Word8) ; put t ; put y
        (MsgQ t x) -> do put (0x02 :: Word8) ; put t ; put x
    get = do
      b1 <- getWord8
      b2 <- getWord8
      t <- get
      if (b1 == 0x02) 
      then case b2 of
             0x01 -> fmap (MsgY t) get
             0x02 -> fmap (MsgQ t) get
             _    -> fail $ "get SimulatorMsg : unknown msg code " ++ show b2
      else fail $ "parseError SimulatorMsg: expected 0x01, got " ++ show b1


