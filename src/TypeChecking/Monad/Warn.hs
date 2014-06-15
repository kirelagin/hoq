{-# LANGUAGE FlexibleInstances, MultiParamTypeClasses #-}

module TypeChecking.Monad.Warn
    ( WarnT, warn, runWarnT
    , throwError, catchError
    ) where

import Control.Monad
import Control.Monad.Trans
import Control.Monad.Error.Class
import Control.Applicative
import Data.Monoid hiding ((<>))

newtype WarnT w m a = WarnT { runWarnT :: m (w, Maybe a) }

instance Functor m => Functor (WarnT w m) where
    fmap f (WarnT m) = WarnT $ fmap (\(w, ma) -> (w, fmap f ma)) m

instance (Monoid w, Applicative m) => Applicative (WarnT w m) where
    pure a = WarnT $ pure (mempty, Just a)
    WarnT f <*> WarnT a = WarnT $ (\(w1, mf) (w2, ma) -> (w1 `mappend` w2, mf <*> ma)) <$> f <*> a

instance (Monoid w, Monad m) => Monad (WarnT w m) where
    return a      = WarnT $ return (mempty, Just a)
    WarnT m >>= k = WarnT $ m >>= \(w, ma) -> case ma of
        Nothing -> return (w, Nothing)
        Just a  -> do
            (w', mb) <- runWarnT (k a)
            return (w `mappend` w', mb)

instance (Monoid w, Monad m) => MonadError w (WarnT w m) where
    throwError w = WarnT $ return (w, Nothing)
    catchError (WarnT m) h = WarnT $ m >>= \(w, ma) -> case ma of
        Nothing -> runWarnT (h w)
        Just _  -> return (w, ma)

instance Monoid w => MonadTrans (WarnT w) where
    lift m = WarnT $ liftM (\a -> (mempty, Just a)) m

instance (Monoid w, MonadIO m) => MonadIO (WarnT w m) where
    liftIO m = WarnT $ liftM (\a -> (mempty, Just a)) (liftIO m)

warn :: Monad m => w -> WarnT w m ()
warn w = WarnT $ return (w, Just ())
