# NASA Final-Failover Web Server With Docker
## Github Location
* [https://github.com/duck105/mezzanine-docker](https://github.com/duck105/mezzanine-docker)

## 組員
* 蕭乙蓁 B05902005 -> mysql備份
* 徐慧能 B05902039 -> docker swarm
* 陳柏文 B05902117 -> web server架構與docker 相關file編寫

## 題目簡述
* 在架設的網站出現錯誤或需要維護的時候，為了不中斷網站的服務，需要一個能夠及時偵測並自動取代出錯部分的的網站備援機制。

* 我們嘗試用Docker取代傳統方式來實作網站備援，並用Nginx 作為 reverse proxy、Mezzanine作為web app、MariaDB作為database。
我們可以做到：
1. 在一台VM上自動化佈署web server、web app、database的Docker container，並在container被停止或移除的數秒內讓網站重新上線。此外，當流量比較大時，我們可以開多台VM(docker swarm的node)來實踐load balance。
2. 嘗試在前述的架構上，再開一台VM，用master-slave的架構備份資料。

## Docker系統簡介
* 為什麼使用Docker？什麼是Docker Container？
  * Docker的目標是實作輕量級的作業系統虛擬化。Container是一種以應用程式為中心的虛擬化技術，和Virtural Machine相比，不需要安裝作業系統便能執行應用程式。因此，使用Docker container可以更快速的啟動和佈署程式、擁有較高的效能、也可以更簡單的管理和更新。

* 建立Container：Docker run & docker-compose 
  * 我們可以透過docker run 指令建立一個container。docker-compose則可以在建立多個container的同時設定他們的連結。

* Docker Engine Swarm mode
  * Docker Engine Swarm mode是從docker1.12之後開始存在的 Docker Engine 原生cluster管理工具，也是我們使用的工具，接下來的swarm都是指Docker Engine Swarm mode。相較於前身的Docker Swarm，增加了更底層技術的支援(ex：network)，並支援docker stack。

* Service & Docker stack 
  * Container上可以運行services，Stack是services的集合，可以方便的自動佈署多個有關聯service。

* Docker Volume 
  * Container在重啟時，先前的更動將會丟失。Volume可以將container以及其產生的數據分離開來，在需要刪除並重啟container時，不會影響先前更動的數據。
  
最後我們用Docker swarm mode 以及Docker stack來做到自動化部屬與備援，而Docker Volume來做資料的保存。 


## 單台VM上container的備援 
* 架構圖(如圖ㄧ)
* 架構簡述：在一台VM上透過自動化佈署新增一個Nginx container、一個Mezzanine container、一個MariaDB container。把VM加入Swarm，利用swarm會監測container狀態、並在container消失時立即重新創出相同container的特性，實現三個服務的備援。

* 自動化生成container
  * 要實作自動化生成，首先我們要準備好docker image，images有兩種來源，一種是直接從Docker Hub上取得官方的image，一種是用Dockerfile，Dockerfile中包含建立container所需的指令，這些指令包含作為基底的現有image、以及其他在image建立程序中需要執行的命令。我們這次部署的三個service中，Nginx跟MariaDB都使用官方的image，Mezzanine的image則用自己寫的Dockerfile來生成。
  
  * Mezzanine Dockerfile:
    * 先用pip安裝mezzanine，並開一個app的repo 
      ```$pip install mezzanine```
      ```$mezzanine-project mezzanine-docker```
      ```$cd mezzanine-docker ```
    * 在requirements.txt中記錄需要安裝的套件，特別是mysqlclient，如此一來Mezzanine才能連接MariaDB。
    * 然後更改 local_settings.py，預設的database是sqlite，將之改成mysql。
    * 接著就可以開始編寫Dockerfile
      ``` $vim Dockerfile ```
    * 這個Dockerfile的重點之一是下行的內容：
      ``` FROM python:3.6 ```
    * 表示這個image使用python的offical image作為基底。我們在上面做一些更動後再變成一個新的image。 
  * docker-compose.yml
    * 接下來要編寫一個docker-compose.yml，其中包含了docker-compose的version，以及需要的三個service，分別是Ｍezzanine(web), Nginx(nginx), MariaDB(db)，括號中為實際的service名稱。
    * 每個service會宣告要用的image file, environment, volumes以及deploy的部分，deploy是為了要結合docker swarm所做的設定。
* 佈署過程
  * 新增一台VM並設定網路
  * 安裝docker 1.13 :會 會使用到docker 1.13的新功能，因此不能用yum install docker (安裝docker 1.12)，而是用官網下載方法。
  * 安裝檔案：為了裝docker-compose 先裝好epel-release 和 python-pip 
    ```$yum -y install vim git epel-release``` 
    ```$yum -y install python-pip``` 
    ```$pip install docker-compose``` 
  * 透過寫好的Dockerfile建立docker image
    ```$git clone https://github.com/duck105/mezzanine-docker.git```
    ```$cd mezzanine-docker```
    ```$docker-compose build```
  * 把VM加入swarm，再用docker 1.13的stack功能執行docker-compose.yml建立的三個service
    ```$docker swarm init```
    ```$docker stack deploy -c docker-compose.yml [stackname]```
  * 進到web那台container的/bin/bash中
    ```$python manage.py createdb --noinput```
    ```$python manage.py collectstatic --noinput```
  就可以成功部署一個Mezzanine的CMS系統了！
* Docker Engine Swarm mode
  * Swarm mode除了能在一台機器上監控與備援docker container，也可以做到load balancing。一開始輸入docker swarm init的機器會被swarm mode視為manager
 
  * 之後我們可以再多開幾台機器，把它們加到swarm中作為manager node或worker node。docker engine會在這些swarm node 中自動找尋適合的分配方式，並分配任意個task給每台機器
  * 當worker的docker engine或整台機器有問題，docker engine會監控到並重新在其他的機器跑一個container來取代，進而做到load balancing，使每台機器的工作量比較平衡，比較不會壞掉。
  
* 遇到的問題
  * 掛載volume時，CentOS中SElinux的權限問題
    * 當我們把設定檔寫好，按照我們以為的正確方法，啟動container後，log卻出現permission denied的問題。經過查詢發現，這個問題源自於SElinux基於安全性，不允許讀取某些目錄下的內容。
    * SElinux預設的類別是svirt_lxc_net_t，此種類別不被允許讀取 /var, /home, /root, /mnt等目錄下的內容。因此，為了讓目錄對應上合適的SELinux policy type label，需要對特定目錄新增規則。例如，想要將volume掛載在/var下，需要執行以下命令更改type的內容：
    ```$chcon -Rt svirt_sandbox_file_t /var/db```
    * 此命令也可以透過在掛載volume時在目錄的尾端加上:z或者:Z參數實現，例如：
    ```$run -v /var/db:/var/db:z rhel7 /bin/sh```
  
  * docker-compose版本問題
    * Docker在1.12版中開始支援swarm mode，也實驗性的推出docker stack來支援多個服務的部屬管理，但未完全與docker compose結合。而且docker-compose version1 / version2都是以container為主，與swarm mode的概念不盡相同。docker 1.13改善了這個問題，並推出docker-compose version3來與swarm 相容。
    * 然而docker1.13在今年才發布，所以我們一開始都是採用version2，在後來必須從version2換成version3時遇到的不少問題。例如v2支援直接用Dockerfile來build image的功能，但在v3中要使用已存在的image，因此要先用docker compose build來precompile等等。而且網路上的教學仍十分稀少，測試了好久才終於成功。
  
  * static file(css、js) 未成功載入
    * 原本只有Mezzanine+MariaDB 的時候沒有這個問題，但是加入Nginx作為reversed proxy 後發現圖片無法載入，網站畫面只剩下很醜的文字和奇怪的排版。經過研究後，發現問題來自於Nginx沒有從Django得到static file。
    * 為了解決這個問題，我們讓Nginx 和Mezzanine 共用一個volume，裡面儲存static file，並在Nginx的設定檔裡寫入要去那個volume找static file。
</br>

## 兩台VM上container的備援和VM中資料的同步與備分(bonus)
* 架構簡述：一台VM的架構可以用服務快速重啟的方式做到備援，但考慮到container的規模較小、損壞機率可能較低，我們嘗試VM層級的備援架構，期望無論是container或是其中一台VM損壞都不會讓資料流失。
* 為了達成這個目標，我們一開始想在database做master-master的資料同步架構，但是因為Docker swarm普遍化的特性(同一個service的docker-compose.yml需要一樣)，造成database需要客製化設定的部分變得很困難(例如每一個node需要不一樣的server_id)。
* 我們盡力想出了一個解決方法，將不同的設定變數都用local檔案的方式讀取，使database的image一致，可以套用到所有VM。這個架構在不加進swarm mode之前是沒問題的：
    * 我們成功架設兩台VM，上面各有一套完整的Nginx+Mezzanine+MariaDB，他們只有database 的部分有連結，在其中一台的網站張貼文章，另外一台也會馬上同步顯示文章。
    * 但是在加進swarm mode裡面後，MariaDB啟動時不會意識到自己是另一台的slave，也沒有互相讀取資料，只好暫時宣告此方案失敗。網路上也沒有找到更好的解法，因此只能期待未來swarm mode能提供對container能客製化設定的方案，以解決這個問題。

* 最後，考量目前較可行的方案，我們改採用master-slave replication的架構，不將slave加進swarm node裡面，只做好備份這項工作。如此一來，雖然swarm 無法控制slave這台機器，但負責備份資料的slave也不會serve出去，出現問題的機率也就比較低。其中master-slave replication的部分，master會紀錄我們修改的數據，而slave會去讀取master的log然後複製一份，如此一來系統更新到 Master 的內容就會及時的備份到 slave 上。
 
* 佈署過程
  * 在單台VM備援的基礎上，再新增一台VM，安裝基本套件
  * 分別在master和slave 的機器開3306 port
  * 在slave機器的repo上：
    * 切換到feature/database_slave的branch
    * 進入mariadb 的設定檔修改他的master ip&server_id
  * docker-compose up就完成了！

## 結論
  * 在這次的project中，我們對於近來主流的web service架構以及架構和備援間的關係有更深一層的了解，也對docker這近期熱門的服務更加熟悉。過程中我們沒有選擇傳統Ansible+VM的方法實作備援，而是使用docker，其實是有利有弊。考量到docker的性質，我們覺得對一個上production的服務而言，docker其實不夠成熟穩定。
  * Docker是一個很新的服務，例如docker swarm mode在去年才推出，而docker stack是今年年初才發布的，他們的相容性問題都還有待加強，網路上也較難找到解決問題的資料。此外，docker swarm 與 mysql replication間的矛盾一直沒有很好的解決方式。不過，雖然docker目前不夠穩定，做為一個網站備援架構，它依舊有不少方便的優點，未來的發展仍然值得期待。

## 附圖ㄧ
![image](https://github.com/duck105/mezzanine-docker/raw/master/single.001.jpeg)
## 附圖二
![image](https://github.com/duck105/mezzanine-docker/raw/master/slave.001.jpeg)
## Structure
 ![image](https://github.com/duck105/mezzanine-docker/raw/master/structure.jpeg)
