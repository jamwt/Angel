module Angel.Job where

import Data.String.Utils (split, strip)
import Data.Maybe (isJust, fromJust)
import System.Process (createProcess, proc, waitForProcess, ProcessHandle)
import System.Process (terminateProcess, CreateProcess(..), StdStream(..))
import Control.Concurrent
import Control.Concurrent.STM
import Control.Concurrent.STM.TVar (readTVar, writeTVar)
import qualified Data.Map as M
import Control.Monad (unless, when, forever)
import System.Directory (getCurrentDirectory, setCurrentDirectory)

import Angel.Log (logger)
import Angel.Data
import Angel.Util (sleepSecs)
import Angel.Files (getFile)

ifEmpty :: String -> IO () -> IO () -> IO ()
ifEmpty s ioa iob = if s == "" then ioa else iob
-- |launch the program specified by `id`, opening (and closing) the
-- |appropriate fds for logging.  When the process dies, either b/c it was
-- |killed by a monitor, killed by a system user, or ended execution naturally,
-- |re-examine the desired run config to determine whether to re-run it.  if so,
-- |tail call.
supervise sharedGroupConfig id = do 
    let log = logger $ "- program: " ++ id ++ " -"
    log "START"
    cfg <- atomically $ readTVar sharedGroupConfig
    let my_spec = find_me cfg
    ifEmpty (name my_spec) 

        (log "QUIT (missing from config on restart)" >> deleteRunning) 
        
        (do
            (attachOut, attachErr) <- makeFiles my_spec cfg

            let (cmd, args) = cmdSplit $ exec my_spec
            let dir =  directory my_spec

            olddir <- getCurrentDirectory
            when (not $ null dir) $ setCurrentDirectory dir
            (_, _, _, p) <- createProcess (proc cmd args){
            std_out = attachOut,
            std_err = attachErr,
            cwd = workingDir my_spec 
            }
            setCurrentDirectory olddir
            
            updateRunningPid my_spec (Just p)
            log "RUNNING"
            waitForProcess p
            log "ENDED"
            updateRunningPid my_spec (Nothing)
            
            cfg <- atomically $ readTVar sharedGroupConfig
            if M.notMember id (spec cfg) 

                then do 
                log  "QUIT"
                deleteRunning

                else do 
                log  "WAITING"
                sleepSecs $ delay my_spec
                log  "RESTART"
                supervise sharedGroupConfig id
        )
        
    where
        cmdSplit fullcmd = (head parts, tail parts) 
            where parts = (filter (/="") . map strip . split " ") fullcmd

        find_me cfg = M.findWithDefault defaultProgram id (spec cfg)
        updateRunningPid my_spec mpid = atomically $ do 
            wcfg <- readTVar sharedGroupConfig
            writeTVar sharedGroupConfig wcfg{
              running=M.insertWith' (\n o-> n) id (my_spec, mpid) (running wcfg)
            }
                
        deleteRunning = atomically $ do 
            wcfg <- readTVar sharedGroupConfig
            writeTVar sharedGroupConfig wcfg{
                running=M.delete id (running wcfg)
            }
            
        makeFiles my_spec cfg = do  
            attachOut <- case stdout my_spec of
                ""    -> return Inherit
                other -> UseHandle `fmap` getFile other cfg
  
            attachErr <- case stderr my_spec of
                ""    -> return Inherit
                other -> UseHandle `fmap` getFile other cfg
            return $ (attachOut, attachErr)


-- |send a TERM signal to all provided process handles
killProcesses :: [ProcessHandle] -> IO ()
killProcesses pids = mapM_ terminateProcess pids

-- |fire up new supervisors for new program ids
startProcesses :: TVar GroupConfig -> [String] -> IO ()
startProcesses sharedGroupConfig starts = mapM_ spawnWatcher starts
    where
        spawnWatcher s = forkIO $ supervise sharedGroupConfig s

-- |diff the requested config against the actual run state, and
-- |do any start/kill action necessary
syncSupervisors :: TVar GroupConfig -> IO ()
syncSupervisors sharedGroupConfig = do 
   let log = logger "process-monitor"
   cfg <- atomically $ readTVar sharedGroupConfig
   let kills = mustKill cfg
   let starts = mustStart cfg
   when (length kills > 0 || length starts > 0) $ log (
         "Must kill=" ++ (show $ length kills)
                ++ ", must start=" ++ (show $ length starts))
   killProcesses kills
   startProcesses sharedGroupConfig starts
                                         
    where
        mustKill cfg = map (fromJust . snd . snd) $ filter (runningAndDifferent $ spec cfg) $ M.assocs (running cfg)
        runningAndDifferent spec (id, (pg, pid)) = (isJust pid && (M.notMember id spec 
                                           || M.findWithDefault defaultProgram id spec `cmp` pg))
            where cmp one two = one /= two

        mustStart cfg = map fst $ filter (isNew $ running cfg) $ M.assocs (spec cfg)
        isNew running (id, pg) = M.notMember id running

-- |periodically run the supervisor sync independent of config reload,
-- |just in case state gets funky b/c of theoretically possible timing
-- |issues on reload
pollStale :: TVar GroupConfig -> IO ()
pollStale sharedGroupConfig = forever $ sleepSecs 10 >> syncSupervisors sharedGroupConfig
