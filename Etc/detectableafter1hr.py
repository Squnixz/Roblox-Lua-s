""" python install ???.py, python start ???.py """
"""ALSO, TS REQUIRES VGC INSTALLED, OTHERWISE IT WILL NOT WORK"""
"""THIS IS NOT FULLY 'EMULATED', OR 'BYPASS' BCZ IT WILL JUST REDUCED THE VGC PERMISSONS. IN THE ENDS, YOU'LL BE BANNED"""
"""IF YOU WANT TO USE TS, MADE SURE YOU USE 'python start ???.py(replace ??? with the name you set)' BEFORE YOU RAN VALORANT! BCZ IF YOU RAN VALORANT FIRST, SOMETHNG WILL NOT BE EMULATED"""
import win32serviceutil
import win32service
import win32event
import servicemanager
import socket
import sys
import win32pipe
import win32file
import threading
import subprocess
import os
import ctypes

class VgcEmulator(win32serviceutil.ServiceFramework):
    _svc_name_ = 'vgc'
    _svc_display_name_ = 'vgc'
    _svc_description_ = ''
    def __init__(self, args):
        win32serviceutil.ServiceFramework.__init__(self, args)
        self.hWaitStop = win32event.CreateEvent(None, 0, 0, None)
        socket.setdefaulttimeout(60)
        self.is_running = True
    def SvcStop(self):
        self.ReportServiceStatus(win32service.SERVICE_STOP_PENDING)
        win32event.SetEvent(self.hWaitStop)
        self.is_running = False
    def SvcDoRun(self):
        servicemanager.LogMsg(servicemanager.EVENTLOG_INFORMATION_TYPE,
                              servicemanager.PYS_SERVICE_STARTED,
                              (self._svc_name_, ''))
        self.main()
    def main(self):
        launch_vgtray = True
        launch_vgm = True
        load_vgk_driver = True
        load_vgrl = True
        load_log_uploader = True
        if launch_vgtray:
            try:
                subprocess.Popen(r'C:\Program Files\Riot Vanguard\vgtray.exe')
            except Exception:
                pass
        if launch_vgm:
            try:
                subprocess.Popen(r'C:\Program Files\Riot Vanguard\vgm.exe')
            except Exception:
                pass
        if load_vgk_driver:
            driver_path = r'C:\Program Files\Riot Vanguard\vgk.sys'
            if os.path.exists(driver_path):
                os.system(f'sc create vgk binPath= "{driver_path}" type= kernel')
                os.system('sc start vgk')
        if load_vgrl:
            vgrl_path = r'C:\Riot Games\Riot Client\vgrl.dll'
            if os.path.exists(vgrl_path):
                try:
                    ctypes.CDLL(vgrl_path)
                except Exception:
                    pass
        if load_log_uploader:
            try:
                subprocess.Popen(r'C:\Program Files\Riot Vanguard\log-uploader.exe')
            except Exception:
                pass
        pipe_thread = threading.Thread(target=self.pipe_server)
        pipe_thread.daemon = True
        pipe_thread.start()
        while self.is_running:
            win32event.WaitForSingleObject(self.hWaitStop, 4500)
        servicemanager.LogMsg(servicemanager.EVENTLOG_INFORMATION_TYPE,
                              servicemanager.PYS_SERVICE_STOPPED,
                              (self._svc_name_, ''))
    def pipe_server(self):
        pipe_name = r'\\.\pipe\933823D3-C77B-4BAE-89D7-A92B567236BC'
        while self.is_running:
            try:
                pipe = win32pipe.CreateNamedPipe(
                    pipe_name,
                    win32pipe.PIPE_ACCESS_DUPLEX,
                    win32pipe.PIPE_TYPE_MESSAGE | win32pipe.PIPE_READMODE_MESSAGE | win32pipe.PIPE_WAIT,
                    1, 65536, 65536, 0, None
                )
                win32pipe.ConnectNamedPipe(pipe, None)
                while True:
                    result, data = win32file.ReadFile(pipe, 65536)
                    if result != 0:
                        break
                    win32file.WriteFile(pipe, data)
            except Exception:
                pass
            finally:
                try:
                    win32file.CloseHandle(pipe)
                except:
                    pass
if __name__ == '__main__':
    if len(sys.argv) == 1:
        servicemanager.Initialize()
        servicemanager.PrepareToHostSingle(VgcEmulator)
        servicemanager.StartServiceCtrlDispatcher()
    else:
        win32serviceutil.HandleCommandLine(VgcEmulator)
