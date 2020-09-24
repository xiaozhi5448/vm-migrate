from fabric import Connection, task, Config
import getpass
import logging
from software_sources import *
logging.basicConfig(level=logging.INFO)

username = 'xiaozhi'
pkgmgr = ''
password = 'wodemima'
connection_args = {
    'password': password
}
config = Config(overrides={'user': username,
                           'connect_kwargs': connection_args})
system_name = ''
version = ''
version_name = ''

proxy_host = '192.168.56.1'
proxy_port = '1088'


@task
def sudo_without_pass(c):
    c.run("sudo chmod +w /etc/sudoers", pty=True)
    c.run("sudo sed -i '/^root/a\{} ALL=(ALL:ALL) NOPASSWD:ALL\n' /etc/sudoers".format(username), pty=True)
    c.run("sudo sed -i '/^\%sudo/a\%{} ALL=(ALL:ALL) NOPASSWD:ALL\n' /etc/sudoers".format(username), pty=True)
    c.run("sudo chmod -w /etc/sudoers", pty=True)


def get_pkg(c):
    global pkgmgr
    try:
        res = c.run("which yum")
        pkgmgr = 'yum'

    except Exception as e:
        pkgmgr = 'apt'


def get_banner(c):
    global system_name, version, version_name
    res = c.run(
        '''cat /etc/os-release | egrep "^ID=" | awk -F= '{print $2}' ''')
    system_name = res.stdout.strip()
    res = c.run(
        ''' cat /etc/os-release | grep "VERSION_ID" | awk -F= '{print $2}' ''')
    version = res.stdout.strip()
    if system_name == 'ubuntu':
        res = c.run('''
                    cat /etc/os-release | grep "VERSION_CODENAME" | awk -F= '{print $2}'
                    ''')
        version_name = res.stdout.strip()


def change_software_source(c):
    if system_name == 'kali':
        try:
            res = c.run('test -f /etc/apt/sources.list')
            c.run('sudo mv /etc/apt/sources.list /etc/apt/sources.list.official')
        except:
            pass
        finally:
            c.run('echo -e "{}" | sudo tee /etc/apt/sources.list'.format(kali_source))
    elif system_name == 'ubuntu':
        try:
            res = c.run('test -f /etc/apt/sources.list')
            c.run('sudo mv /etc/apt/sources.list /etc/apt/sources.list.official')
        except:
            pass
        finally:
            c.run(
                'echo -e "{}" | sudo tee /etc/apt/sources.list'.format(ubuntu_source.format(version_name)))

    elif system_name == 'centos':
        try:
            c.run('test -d /etc/yum.repos.d')
            c.run(
                'sudo mv /etc/yum.repos.d /etc/yum.repos.d.official && sudo mkdir /etc/yum.repos.d')
        except:
            pass
        finally:
            c.run('echo -e "{}" | sudo tee /etc/yum.repos.d/CentOS-Base.repo'.format(
                centos_source.format(version)))
    else:
        logging.error('unrecognized system!')
    c.run("sudo {} update -y".format(pkgmgr))


def install_deps(c):
    if system_name in ['kali', 'ubuntu']:
        c.run("""sudo {} install -y gcc make build-essential libssl-dev zlib1g-dev \
                libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev \
                libncursesw5-dev xz-utils tk-dev libffi-dev liblzma-dev\
                gcc g++ make cmake git build-essential open-vm-tools linux-headers-$(uname -r)""".format(pkgmgr))
    elif system_name == 'centos':
        c.run('''sudo {} install -y zlib-devel bzip2-devel openssl-devel ncurses-devel\
               sqlite-devel readline-devel tk-devel libffi-devel\
               gcc gcc-c++ make cmake git kernel-devel'''.format(pkgmgr))


def install_proxychains(c):
    if system_name in ['ubuntu', 'kali']:
        c.run("sudo {} install {} -y".format(pkgmgr, "proxychains"))
        c.run('''
              sudo sed -i 's/^socks4.*/socks5 {} {}/g' /etc/proxychains.conf
              '''.format(proxy_host, proxy_port))
    elif system_name == 'centos':
        pass


def install_pyenv(c):
    try:
        c.run("test -d /home/{}/.pyenvd".format(username))
    except:
        c.run("proxychains curl -L https://github.com/pyenv/pyenv-installer/raw/master/bin/pyenv-installer > /home/{}/pyenv-installer.sh".format(username))
        c.run("sed -i '/^ProxyChains.*/d' /home/{}/pyenv-installer.sh".format(username))
        c.run("proxychains sh /home/{}/pyenv-installer.sh".format(username))

        c.run('''cat << EOF  >> /home/{}/.bashrc
        export PATH="/home/{}/.pyenv/bin:\$PATH"
        eval "\$(pyenv init -)"
        eval "\$(pyenv virtualenv-init -)"
                      '''.format(username, username))
        c.run("source /home/{}/.bashrc".format(username))
    try:
        c.run("mkdir -p /home/{}/.pyenv/cache".format(username))
    except:
        logging.info("cache dir already exists!")
        pass
    c.put('Miniconda3-3.8.3-Linux-x86_64.sh',
          '/home/{}/.pyenv/cache/'.format(username))
    c.run("pyenv install miniconda3-3.8.3")
    c.run("sudo apt install python-pip -y")
    c.run('sudo pip install -U pip  -i https://pypi.tuna.tsinghua.edu.cn/simple some-package')
    c.run('pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple')
    c.run('sudo pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple')
    c.put('.condarc', '/home/{}/'.format(username))
    c.run('sudo cp /home/{}/.condarc /root/'.format(username))


def install_java(c):
    try:
        res = c.run('test -d /usr/local/java/jdk')
        logging.info('java has been already configured!')
        return
    except:
        pass
    c.put('jdk-8u261-linux-x64.tar.gz', '/home/{}/'.format(username))
    c.put('jdk-14.0.2_linux-x64_bin.tar.gz', '/home/{}/'.format(username))
    c.run('sudo mkdir -p /usr/local/java')
    c.run('sudo mv /home/{}/jdk-8u261-linux-x64.tar.gz /home/{}/jdk-14.0.2_linux-x64_bin.tar.gz /usr/local/java/'.format(username, username))
    c.run('sudo tar -xf /usr/local/java/jdk-8u261-linux-x64.tar.gz -C /usr/local/java/')
    c.run('sudo tar -xf /usr/local/java/jdk-14.0.2_linux-x64_bin.tar.gz -C /usr/local/java/')
    logging.info("jdk archive uncompressed!")
    c.run('sudo ln -s /usr/local/java/jdk-14.0.2 /usr/local/java/jdk')
    c.run('''
          cat << EOF >> ~/.bashrc
          export JAVA_HOME="/usr/local/java/jdk"
          export PATH="/usr/local/java/jdk/bin:\$PATH"
          ''')


def install_docker(c):
    c.run('sudo apt install docker.io docker-compose -y')
    c.run('sudo mkdir -p /etc/docker')
    c.run('''sudo tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": ["https://e4y65rvy.mirror.aliyuncs.com"]
}
EOF
          ''')
    c.run('sudo systemctl daemon-reload')
    c.run('sudo systemctl restart docker')


def install_vim(c):
    pass


if __name__ == '__main__':
    c = Connection('192.168.56.104', config=config)
    get_pkg(c)
    # logging.info('find package manager:{}'.format(pkgmgr))
    get_banner(c)
    # logging.info('find system: {}, version: {}'.format(system_name, version))
    # change_software_source(c)
    # install_deps(c)
    # install_proxychains(c)
    # install_pyenv(c)
    install_java(c)
    # install_docker(c)
    c.close()
