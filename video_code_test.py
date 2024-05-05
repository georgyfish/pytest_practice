#!/usr/bin/python3

import os
import subprocess
import time
import paramiko
import pytest


def check_mpv():
    command = f"dpkg -l |grep -i mpv"
    result = subprocess.check_output(command, shell=True).decode('utf-8').split('\n')
    if not result:
        print('install mpv...')
        os.system('sudo apt install mpv -y')

def scp_testdata(remote_host, remote_user, remote_pass,remote_path,local_path):

    # # 远程服务器的信息
    # remote_host = '192.168.100.242'
    # remote_port = 22
    # remote_user = 'user'
    # remote_pass = 'gfx123456'
    # remote_path = '/var/www/data/testdata/'

    # # 本地服务器的信息
    # local_path = '/home/swqa/'

    # 创建SSH客户端对象
    # ssh = paramiko.SSHClient()
    # ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    # # 连接远程服务器
    # ssh.connect(remote_host, remote_port, remote_user, remote_pass)

    # # 执行SCP命令，将文件从远程服务器复制到本地
    # stdin, stdout, stderr = ssh.exec_command(f'scp {remote_path} {local_path}')

    # # 关闭SSH连接
    # ssh.close()
    os.system('sudo apt-get -y install sshpass')
    
    os.system(f" sshpass -p '{remote_pass}' scp -r {remote_user}@{remote_host}:{remote_path} {local_path} ")

def find_files(directory):
    file_formats = {}

    for root, dirs, files in os.walk(directory):
        for file in files:
            # 获取文件的扩展名
            extension = os.path.splitext(file)[1]
            # 将格式添加到对应列表中
            if extension not in file_formats:
                file_formats[extension] = []
            file_formats[extension].append(os.path.join(root, file))

    return file_formats


def get_encode_files(directory):
    file_formats = {} 
    # 视频文件：编码格式
    for root, dirs, files in os.walk(directory):
        for file in files:
            # print(file,os.path.join(root, file))
            cmd = f"ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 '{os.path.join(root, file)}'"
            # file_code = subprocess.Popen(cmd,shell=True)    
            file_code = subprocess.check_output(cmd, shell=True).decode('utf-8')
            if file_code != '':
                # if file_code != []:
                file_code = file_code.split()[0]
                
                if file_code not in file_formats:
                    file_formats[file_code] = []
                    # print(file_code,type(file_code))
                file_formats[file_code].append(os.path.join(root,file))
    return file_formats
           
    #         if file_code not in  file_formats:
    #             file_formats[file_code] = []
    #             file_formats[file_code].append(os.path.join(root, file))
    #         # file_formats[file] = file_code
    # return file_formats


def check_decode_status():
    decode_status_command = "sudo cat /sys/kernel/debug/mtvpu0/info |grep fps"
    os.system('sleep 5')
    result = subprocess.check_output(decode_status_command, shell=True).decode('utf-8').split('\n')
    if result:
        return True
    else:
        return False

def hard_decode_video(video_file):
    try:
        #os.system('killall mpv')
        command = f" export WAYLAND_DISPLAY=wayland-0 DISPLAY=:0 XAUTHORITY=/run/user/1000/.mutter-Xwaylandauth.FBBDN2 \
            && timeout 30 mpv --hwdec=vaapi --vo=gpu '{video_file}' --fs --loop &"
        # command = f" export DISPLAY=:0.0 && timeout {time}  deepin-movie  '{video_file}' &"
        print(command)
        cmd_ouput = subprocess.run(command, shell=True, stdout=subprocess.PIPE).stdout.decode()
        ouput_list = cmd_ouput.split('\n')
        for out in ouput_list:
            if "Using hardware decoding" in out:
                print('正在使用硬解')
                return True
        if not check_decode_status():
            return False
    except subprocess.CalledProcessError:
        return False

def test_av1():
    assert hard_decode_video('/home/georgy/Desktop/testdata/video/DVT/Test_1080P.mp4') == False

# @pytest.mark.parametrize(
#     "video_file,expected",
#     [
#         ('/home/swqa/testdata/mm_video/1080P/AV1_8BIT',False),
#         (),
#         (),
#     ]
# )

def main():
    # directory = '/home/swqa/testdata/mm_video/1080P/'  # 替换视频文件夹路径
    directory = '/home/georgy/Desktop/testdata/video/DVT/'
    # file_formats = find_files(directory)
    file_formats = get_encode_files(directory)
    # print(file_formats)
    check_mpv()
    print("\n找到的编码格式如下：")
    for video_code, files in file_formats.items():
        print("编码格式 %s :" % video_code)
        for file in files:
            print("  %s" % file)
    # formats = get_video_formats(directory)
    # print("Detected video formats:", formats)
    for video_code in file_formats.keys():
        print('=='*50)
        print(f"Try Hard decoding videos in format {video_code}...")
        # files = [f for f in os.listdir(directory) if f.endswith(extension)]
        files = file_formats[video_code]
        success_count = 0
        fail_count = 0
        for file in files:
            print(f"Hard decoding video:{file}")
            file_path = f"{os.path.join(directory, file)}"
            # print(file_path)
            result = hard_decode_video(file_path)
            print(result)
            time.sleep(20)
            if result:
                success_count += 1
            else:
                fail_count += 1
                print(f"Failed hard decoding {video_code} video: {os.path.join(directory, file)}")
        print(f"Hard decoding of {video_code} videos finished. Successful count: {success_count}")
        print(f"Hard decoding of {video_code} videos finished. Failed count: {fail_count}")
        # print('=='*50)

if __name__ == "__main__":
    # main()
    pass