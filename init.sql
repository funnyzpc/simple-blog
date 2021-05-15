
-- DROP TABLE public.t_blog;

CREATE TABLE public.t_blog (
   id numeric(20) NOT NULL,
   subject varchar(30) NOT NULL,
   title varchar(200) NOT NULL,
   "content" text NOT NULL,
   user_id varchar(20) NULL,
   origin varchar(100) NULL,
   visited varchar(100) NOT NULL,
   "type" bpchar(1) NOT NULL,
   status bpchar(1) NOT NULL,
   update_date timestamp NULL,
   create_date timestamp NOT NULL,
   CONSTRAINT t_article_pkey PRIMARY KEY (id)
);


INSERT INTO public.t_blog (id,subject,title,"content",user_id,origin,visited,"type",status,update_date,create_date) VALUES
	 (1004,'技术','node+puppeteer+express搭建截图服务','
### 使用node+puppeteer+express搭建截图服务

>转载请注明出处[https://www.cnblogs.com/funnyzpc/p/14222807.html](https://www.cnblogs.com/funnyzpc/p/14222807.html)

#### 写在之前
  一开始我们的需求是打开报表的某个页面然后把图截出来，然后调用企业微信发送给业务群
  这中间我尝试了多种技术，比如`html2image`，`pdf2image`、`selenium`这些，这其中截图
  比体验较好的也就`selenium`了，不过我们有些页面加载的时间较长，selenium似乎对html互操作性
  也不是很完美(通过Thread.sleep并不能完美的兼容绝大多数报表)，另外还有一个比较要命的
  是Chromium渲染出来的页面似乎也有不同程度的问题(就是不好看),当然后面一个偶然的机会在
  某不知名网站看到有网友用`puppeteer`来实现截图，遂~，一通骚操作就搭了一套出来(虽然最终方案并不是这个
  ,当然这是后话哈～)，这里就拿出来说说哈～
  
#### 准备
由于整个系统是基于node+express的web服务，puppeteer只是node的一个plugin，所以需要做的准备大致有下
+ 一台linux服务器，这里实用centos
+ node安装包(用于搭建node环境)
+ 字体文件


#### 安装node环境
+ `wget https://nodejs.org/dist/v14.15.3/node-v14.15.3-linux-x64.tar.xz`
+ `tar --strip-components 1 -xvJf node-v* -C /usr/local`
+ `npm config set registry https://registry.npm.taobao.org`
  
#### 安装pm2(用于守护node服务)

【注意：安装pm2前必须安装npm，如果只是非正式环境可以不用安装pm2】
+ `npm install pm2 -g`
+ 其它操作请见[https://pm2.keymetrics.io](https://pm2.keymetrics.io)

#### 安装字体

  【这个其实很重要，我也绕了弯，原本以为改改字体编码就可以了，后来发现不是】
+ step1: 将window字体复制到linux下
  - windows: C:\Windows\Fonts
  - Linux: /usr/share/fonts/
+ step2: 建立字体索引信息并更新字体缓存
  - cd /usr/share/fonts/
  - mkfontscale
  - mkfontdir
  - fc-cache  

#### 准备代码
+ index.js
```
// 引入express module
// 引入puppeteer module
const express = require(''express''),
    app = express(),
    puppeteer = require(''puppeteer'');

// 函数::页面加载监控
const waitTillHTMLRendered = async (page, timeout = 30000) => {
  const checkDurationMsecs = 1000;
  const maxChecks = timeout / checkDurationMsecs;
  let lastHTMLSize = 0;
  let checkCounts = 1;
  let countStableSizeIterations = 0;
  const minStableSizeIterations = 3;

  while(checkCounts++ <= maxChecks){
    let html = await page.content();
    let currentHTMLSize = html.length;
    let bodyHTMLSize = await page.evaluate(() => document.body.innerHTML.length);
    console.log(''last: '', lastHTMLSize, '' <> curr: '', currentHTMLSize, " body html size: ", bodyHTMLSize);
    if(lastHTMLSize != 0 && currentHTMLSize == lastHTMLSize)
      countStableSizeIterations++;
    else
      countStableSizeIterations = 0; //reset the counter

    if(countStableSizeIterations >= minStableSizeIterations) {
      console.log("Page rendered fully..");
      break;
    }
    lastHTMLSize = currentHTMLSize;
    await page.waitFor(checkDurationMsecs);
  }
};

//创建一个 `/screenshot` 的route
app.get("/screenshot", async (request, response) => {
  try {
        const browser = await puppeteer.launch({ args: [''--no-sandbox''] });
        const page = await browser.newPage();
        await page.setViewport({
                            width:!request.query.width?1600:Number(request.query.width),
                            height:!request.query.height?900:Number(request.query.height)
                                                        });
        // 这里执行登录操作(非公共页面需要登录)
        if(request.query.login && request.query.login=="true"){
                // wait until page load
                await page.goto(''认证(登录)地址'', { waitUntil: ''networkidle0'' });
                await page.type(''#username'', ''登录用户名'');
                await page.type(''#password'', ''登录密码'');
                // click and wait for navigation
                await Promise.all([
                        page.click(''#loginBtn''),
                        page.waitForNavigation({ waitUntil: ''networkidle0'' }),
                ]);
        }
        await page.goto(request.query.url,{''timeout'': 12000, ''waitUntil'':''load''});
        await waitTillHTMLRendered(page);
    const image = await page.screenshot({fullPage : true,margin: {top: ''100px''}});
    await browser.close();
    response.set(''Content-Type'', ''image/png'');
    response.send(image);
  } catch (error) {
    console.log(error);
  }
});
// listener 监听 3000端口
var listener = app.listen(3000, function () {
  console.log(''Your appliction is listening on port '' + listener.address().port);
});
```
+ package.json
```
{
  "name": "funnyzpc",
  "version": "1.0.0",
  "description": "",
  "main": "index.js",
  "scripts": {
    "test": "echo \"Error: no test specified\" && exit 1"
  },
  "author": "",
  "license": "ISC"
}

```

#### 依赖安装
+ `npm i --save puppeteer express`

  [注意：如果安装失败 请检查是否更改为taobao源]

#### 启动及管理
+ 直接使用node启动服务
  - `node index.js`
+ 使用pm2启动(如果安装了pm2)
  - 启动：`pm2 start index.js`
  - 进程：`pm2 list`
  - 删除：`pm2 delete 应用ID`
  
#### 使用
由于以上代码已经对截图的加载做过处理的，所以无需在使用线程睡眠
同时代码也对宽度(width)和高度(height)做了处理，所以具体访问地址如下

`http://127.0.0.1:3000/screenshot/?login=[是否登录true or false]&width=[页面宽度]&height=[页面高度]&url=[截图地址]`

#### 最后
虽然我们我们使用`puppeteer`能应对绝大多数报表，后来发现`puppeteer`对多组件图表存在渲染问题，所以就要求
提供商提供导出图片功能(用户页面导出非api)，所以最终一套就是 http模拟登录+调用截图接口+图片生成监控+推送图片
好了，关于截图就分享到这里了，各位元旦节快乐哈～《@.@》
','1','会飞的企鹅','0','2','2','2021-03-04 20:42:50.098296','2021-03-04 20:42:50.098296'),
	 (1006,'技术','PostgreSQL使用MySQL外表(mysql_fdw)','
### postgres使用mysql外表

> 转载请注明出处[https://www.cnblogs.com/funnyzpc/p/14223167.html](https://www.cnblogs.com/funnyzpc/p/14223167.html)

#### 浅谈
  &nbsp;&nbsp; `postgres`不知不觉已经升到了版本13,记得两年前还是版本10，当然这中间一直期望着哪天能在项目中使用postgresql，现在已实现哈～；
  顺带说一下：使用`postgresql` 的原因是它的生态完整，还有一个很重要的点儿是 `速度快` 这个在第10版的时 这么说也许还为时过早，
  但是在13这一版本下一点儿也不为过,真的太快了，我简单的用500w的数据做聚合，在不建立索引(主键除外)的情况下 执行一个聚合操作，postgres
  的速度是`mysql`的8倍，真的太快了～；好了，这一章节我就聊一聊我实际碰到的问题，就是：跨库查询，这里是用mysql_fdw实现的。
  
#### 环境准备
+ 一个`mysql`实例(5.7或8均可)
+ 一个`postgres`实例(这里使用源码编译安装的13，建议13，11或12也可)
+ 一台linux（以下内容使用的是`centos`,其它系统也可参考哈）

  以下内容仅仅为安装及使用mysql_fdw的教程，具体mysql及postgres怎么安装我就一并略去

#### 准备libmysqlclient

  注意：若mysql与postgresql在同一台linux机上，则无需安装mysql工具，请略过本段
+ `wget https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-8.0.22-linux-glibc2.17-x86_64-minimal.tar.xz`
+ `tar -xvJf mysql-8.0.22-linux-glibc2.17-x86_64-minimal.tar.xz`
+ ` chown -R mysql:mysql /usr/local/mysql/`
+ `cd mysql-8.0.22-linux-glibc2.17-x86_64-minimal`
+ `cp -r ./* /usr/local/mysql/`

#### 配置环境变量

+ 配置文件

  ```vi /etc/profile```

+ 添加mysql环境变量
  ```
  export MYSQL_HOME=/usr/local/mysql
  export PATH=$PATH:/usr/local/mysql/bin
  export LD_LIBRARY_PATH=MYSQL_HOME/lib:$LD_LIBRARY_PATH
  ```

+ 添加postgres环境变量
  ```
  export PG_HOME=/usr/local/pgsql
  export LD_LIBRARY_PATH=$PG_HOME/lib:$MYSQL_HOME/lib:/lib64:/usr/lib64:/usr/local/lib64:/lib:/usr/lib:/usr/local/lib
  export PATH=$PG_HOME/bin:$MYSQL_HOME/bin:$PATH:.
  ```

+ 刷新配置

  `  source  /etc/profile `

#### 下载并编译mysql_fdw
+ 下载地址: 
 [https://github.com/EnterpriseDB/mysql_fdw/releases](https://github.com/EnterpriseDB/mysql_fdw/releases)
 
+ 解压

  `tar -xzvf REL-2_5_5.tar.gz`
  
+ 进入

  `cd  mysql_fdw-REL-2_5_5`
 
+ 编译 

  `make USE_PGXS=1`
  
+ 安装 

  `make USE_PGXS=1 install`

#### 重启postgres
 
  安装mysql_fdw 并 配置完成环境变量必须重启postgresql,这个很重要
  
  ```
    su postgres
    /usr/local/pgsql/bin/pg_ctl -D /mnt/postgres/data -l logfile stop
    /usr/local/pgsql/bin/pg_ctl -D /mnt/postgres/data -l logfile start
    psql [ or /usr/local/pgsql/bin/psql]
  ```

#### 登录到postgres并配置mysql_server
+ 切换到指定数据库(很重要!!!): `\c YOUR_DB_NAME`
+ `CREATE EXTENSION mysql_fdw;`
+ `CREATE SERVER mysql_server FOREIGN DATA WRAPPER mysql_fdw OPTIONS (host ''HOST'', port ''3306'');`
+ `CREATE USER MAPPING FOR YOUR_DB_NAME SERVER mysql_server OPTIONS  (username ''USERNAME'', password ''PASSWORD'');`
+ `GRANT USAGE ON FOREIGN SERVER mysql_server TO YOUR_DB_NAME;`
+ `GRANT ALL PRIVILEGES ON ods_tianmao_transaction TO YOUR_DB_NAME;`

#### 创建外表

  创建的外表必须在mysql中有对应的表，否则无法使用(也不会在DB工具中显示)
  
+ 样例

  ```
  CREATE FOREIGN TABLE YOUR_TABLE_NAME(
    id  numeric(22),
    date date ,
    name varchar(50),
    create_time timestamp 
  )SERVER mysql_server OPTIONS (dbname ''YOUR_DB_NAME'', table_name ''MYSQL_TABLE_NAME'');
  ```

#### 删除操作
+ 删除扩展 

  `DROP EXTENSION mysql_fdw CASCADE;`

+ 删除mysql_server 

  `DROP SERVER [mysql_server] CASCADE;`

+ 删除外表

  `DROP FOREIGN TABLE [YOUR_FOREIGN_TABLE_NAME] CASCADE;`

+ 修改user mapping
  ```
  ALTER USER MAPPING FOR YOUR_DB_USER SERVER mysql_server OPTIONS (SET password ''PASSWORD'');
  ALTER USER MAPPING FOR YOUR_DB_USER SERVER mysql_server OPTIONS (SET username ''USERNAME'');
  ```

#### 最后

  &nbsp;&nbsp;想说的是postgresql的外表功能实在是太好用了，建立mysql外表后可直接在posgresql中执行增删改查等操作
  更强大的是 还可以执行与postgresql表的连表查询，真香~，省去了应用配置数据源的麻烦。😂','1','梦中的我','0','2','2','2021-04-19 09:19:49.157402','2021-04-19 09:19:49.157402'),
	 (1002,'技术','postgres使用mysql外表','
### postgres使用mysql外表

> 转载请注明出处[https://www.cnblogs.com/funnyzpc/p/14223167.html](https://www.cnblogs.com/funnyzpc/p/14223167.html)

#### 浅谈
  &nbsp;&nbsp; `postgres`不知不觉已经升到了版本13,记得两年前还是版本10，当然这中间一直期望着哪天能在项目中使用postgresql，现在已实现哈～；
  顺带说一下：使用`postgresql` 的原因是它的生态完整，还有一个很重要的点儿是 `速度快` 这个在第10版的时 这么说也许还为时过早，
  但是在13这一版本下一点儿也不为过,真的太快了，我简单的用500w的数据做聚合，在不建立索引(主键除外)的情况下 执行一个聚合操作，postgres
  的速度是`mysql`的8倍，真的太快了～；好了，这一章节我就聊一聊我实际碰到的问题，就是：跨库查询，这里是用mysql_fdw实现的。
  
#### 环境准备
+ 一个`mysql`实例(5.7或8均可)
+ 一个`postgres`实例(这里使用源码编译安装的13，建议13，11或12也可)
+ 一台linux（以下内容使用的是`centos`,其它系统也可参考哈）

  以下内容仅仅为安装及使用mysql_fdw的教程，具体mysql及postgres怎么安装我就一并略去

#### 准备libmysqlclient

  注意：若mysql与postgresql在同一台linux机上，则无需安装mysql工具，请略过本段
+ `wget https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-8.0.22-linux-glibc2.17-x86_64-minimal.tar.xz`
+ `tar -xvJf mysql-8.0.22-linux-glibc2.17-x86_64-minimal.tar.xz`
+ ` chown -R mysql:mysql /usr/local/mysql/`
+ `cd mysql-8.0.22-linux-glibc2.17-x86_64-minimal`
+ `cp -r ./* /usr/local/mysql/`

#### 配置环境变量

+ 配置文件

  ```vi /etc/profile```

+ 添加mysql环境变量
  ```
  export MYSQL_HOME=/usr/local/mysql
  export PATH=$PATH:/usr/local/mysql/bin
  export LD_LIBRARY_PATH=MYSQL_HOME/lib:$LD_LIBRARY_PATH
  ```

+ 添加postgres环境变量
  ```
  export PG_HOME=/usr/local/pgsql
  export LD_LIBRARY_PATH=$PG_HOME/lib:$MYSQL_HOME/lib:/lib64:/usr/lib64:/usr/local/lib64:/lib:/usr/lib:/usr/local/lib
  export PATH=$PG_HOME/bin:$MYSQL_HOME/bin:$PATH:.
  ```

+ 刷新配置

  `  source  /etc/profile `

#### 下载并编译mysql_fdw
+ 下载地址: 
 [https://github.com/EnterpriseDB/mysql_fdw/releases](https://github.com/EnterpriseDB/mysql_fdw/releases)
 
+ 解压

  `tar -xzvf REL-2_5_5.tar.gz`
  
+ 进入

  `cd  mysql_fdw-REL-2_5_5`
 
+ 编译 

  `make USE_PGXS=1`
  
+ 安装 

  `make USE_PGXS=1 install`

#### 重启postgres
 
  安装mysql_fdw 并 配置完成环境变量必须重启postgresql,这个很重要
  
  ```
    su postgres
    /usr/local/pgsql/bin/pg_ctl -D /mnt/postgres/data -l logfile stop
    /usr/local/pgsql/bin/pg_ctl -D /mnt/postgres/data -l logfile start
    psql [ or /usr/local/pgsql/bin/psql]
  ```

#### 登录到postgres并配置mysql_server
+ 切换到指定数据库(很重要!!!): `\c YOUR_DB_NAME`
+ `CREATE EXTENSION mysql_fdw;`
+ `CREATE SERVER mysql_server FOREIGN DATA WRAPPER mysql_fdw OPTIONS (host ''HOST'', port ''3306'');`
+ `CREATE USER MAPPING FOR YOUR_DB_NAME SERVER mysql_server OPTIONS  (username ''USERNAME'', password ''PASSWORD'');`
+ `GRANT USAGE ON FOREIGN SERVER mysql_server TO YOUR_DB_NAME;`
+ `GRANT ALL PRIVILEGES ON ods_tianmao_transaction TO YOUR_DB_NAME;`

#### 创建外表

  创建的外表必须在mysql中有对应的表，否则无法使用(也不会在DB工具中显示)
  
+ 样例

  ```
  CREATE FOREIGN TABLE YOUR_TABLE_NAME(
    id  numeric(22),
    date date ,
    name varchar(50),
    create_time timestamp 
  )SERVER mysql_server OPTIONS (dbname ''YOUR_DB_NAME'', table_name ''MYSQL_TABLE_NAME'');
  ```

#### 删除操作
+ 删除扩展 

  `DROP EXTENSION mysql_fdw CASCADE;`

+ 删除mysql_server 

  `DROP SERVER [mysql_server] CASCADE;`

+ 删除外表

  `DROP FOREIGN TABLE [YOUR_FOREIGN_TABLE_NAME] CASCADE;`

+ 修改user mapping
  ```
  ALTER USER MAPPING FOR YOUR_DB_USER SERVER mysql_server OPTIONS (SET password ''PASSWORD'');
  ALTER USER MAPPING FOR YOUR_DB_USER SERVER mysql_server OPTIONS (SET username ''USERNAME'');
  ```

#### 最后

  &nbsp;&nbsp;想说的是postgresql的外表功能实在是太好用了，建立mysql外表后可直接在posgresql中执行增删改查等操作
  更强大的是 还可以执行与postgresql表的连表查询，真香~，省去了应用配置数据源的麻烦。','5','小小','377','2','0','2021-03-04 11:10:20.971105','2019-12-01 12:51:52.374003'),
	 (1001,'故事',' 记一次订单号事故','### 记一次订单号事故

>  去年年底的时候，我们线上出了一次事故，这个事故的表象是这样的:
>系统出现了两个一模一样的订单号，订单的内容却不是不一样的，而且系统在按照
>订单号查询的时候一直抛错，也没法正常回调，而且事情发生的不止一次，所以
>这次系统升级一定要解决掉。

  经手的同事之前也改过几次，不过效果始终不好：总会出现订单号重复的问题，
所以趁着这次问题我好好的理了一下我同事写的代码。

  这里简要展示下当时的代码：

```
      /**
  	 * OD单号生成
  	 * 订单号生成规则：OD + yyMMddHHmmssSSS + 5位数(商户ID3位+随机数2位) 22位
  	 */
  	public static String getYYMMDDHHNumber(String merchId){
          StringBuffer orderNo = new StringBuffer(new SimpleDateFormat("yyMMddHHmmssSSS").format(new Date()));
          if(StringUtils.isNotBlank(merchId)){
              if(merchId.length()>3){
                  orderNo.append(merchId.substring(0,3));
              }else {
                  orderNo.append(merchId);
              }
          }
          int orderLength = orderNo.toString().length();
          String randomNum = getRandomByLength(20-orderLength);
          orderNo.append(randomNum);
          return orderNo.toString();
  	}
  
  
      /** 生成指定位数的随机数 **/
      public static String getRandomByLength(int size){
          if(size>8 || size<1){
              return "";
          }
          Random ne = new Random();
          StringBuffer endNumStr = new StringBuffer("1");
          StringBuffer staNumStr = new StringBuffer("9");
          for(int i=1;i<size;i++){
              endNumStr.append("0");
              staNumStr.append("0");
          }
          int randomNum = ne.nextInt(Integer.valueOf(staNumStr.toString()))+Integer.valueOf(endNumStr.toString());
          return String.valueOf(randomNum);
      }
```

  可以看到，这段代码写的其实不怎么好，代码部分暂且不议，代码中使订单号不重复的主要因素点是随机数和毫秒，可是这里的随机数只有两位
在高并发环境下极容易出现重复问题，同时毫秒这一选择也不是很好，在多核CPU多线程下，一定时间内(极小的)这个毫秒可以说是固定不变的(测试验证过)，所
以这里我先以100个并发测试下这个订单号生成，测试代码如下：
```
    public static void main(String[] args) {
        final String merchId = "12334";
        List<String> orderNos = Collections.synchronizedList(new ArrayList<String>());
        IntStream.range(0,100).parallel().forEach(i->{
            orderNos.add(getYYMMDDHHNumber(merchId));
        });

        List<String> filterOrderNos = orderNos.stream().distinct().collect(Collectors.toList());

        System.out.println("生成订单数："+orderNos.size());
        System.out.println("过滤重复后订单数："+filterOrderNos.size());
        System.out.println("重复订单数："+(orderNos.size()-filterOrderNos.size()));
    }
```
果然，测试的结果如下：
```
生成订单数：100
过滤重复后订单数：87
重复订单数：13

```
  当时我就震惊🤯了，一百个并发里面竟然有13个重复的！！！，我赶紧让同事先不要发版，这活儿我接了！
  
  对这一烫手的山竽拿到手里没有一个清晰的解决方案可是不行的，我大概花了6+分钟和同事商量了下业务场景，决定做如下更改：

+ 去掉商户ID的传入(按同事的说法,传入商户ID也是为了防止重复订单的，事实证明并没有叼用)
+ 毫秒仅保留三位(缩减长度同时保证应用切换不存在重复的可能)
+ 使用线程安全的计数器做数字递增(三位数最低保证并发800不重复,代码中我给了4位)
+ 更换日期转换为java8的日期类以格式化(线程安全及代码简洁性考量)

经过以上思考后我的最终代码是：
```
    /** 订单号生成(NEW) **/
    private static final AtomicInteger SEQ = new AtomicInteger(1000);
    private static final DateTimeFormatter DF_FMT_PREFIX = DateTimeFormatter.ofPattern("yyMMddHHmmssSS");
    private static ZoneId ZONE_ID = ZoneId.of("Asia/Shanghai");
    public static String generateOrderNo(){
        LocalDateTime dataTime = LocalDateTime.now(ZONE_ID);
        if(SEQ.intValue()>9990){
            SEQ.getAndSet(1000);
        }
        return  dataTime.format(DF_FMT_PREFIX)+SEQ.getAndIncrement();
    }

```

  当然代码写完成了可不能这么随随便便结束了，现在得走一个测试main函数看看：

```
    public static void main(String[] args) {

        List<String> orderNos = Collections.synchronizedList(new ArrayList<String>());
        IntStream.range(0,8000).parallel().forEach(i->{
            orderNos.add(generateOrderNo());
        });

        List<String> filterOrderNos = orderNos.stream().distinct().collect(Collectors.toList());

        System.out.println("生成订单数："+orderNos.size());
        System.out.println("过滤重复后订单数："+filterOrderNos.size());
        System.out.println("重复订单数："+(orderNos.size()-filterOrderNos.size()));
    }
    
    /**
        测试结果： 
        生成订单数：8000
        过滤重复后订单数：8000
        重复订单数：0
    **/
```

  真好，一次就成功了，可以直接上线了。。。
  
  然而，我回过头来看以上代码，虽然最大程度解决了并发单号重复的问题，不过对于我们的系统架构还是有一个潜在的隐患： 如果当前
  应用有多个实例(集群)难道就没有重复的可能了？
  鉴于此问题就必然需要一个有效的解决方案，所以这时我就思考：多个实例应用订单号如何区分开呢？以下为我思考的大致方向：

+ 使用UUID(在第一次生成订单号时初始化一个)
+ 使用redis记录一个增长ID
+ 使用数据库表维护一个增长ID
+ 应用所在的网络IP
+ 应用所在的端口号
+ 使用第三方算法(雪花算法等等)
+ 使用进程ID(某种程度下是一个可行的方案)

  在此我想了下，我们的应用是跑在docker里面，而且每个docker容器内的应用端口都一样，不过网路IP不会存在重复的问题，至于进程也有存在重复的可能，
  对于UUID的方式之前吃过亏，远之吧，redis或DB也算是一种比较好的方式，不过独立性较差。。。，同时还有一个因素也很重要，就是所有涉及到订单号生成的
  应用都是在同一台宿主机(linux实体服务器)上， 所以就目前的系统架构我选用了IP的方式。
  一下是我的代码：

```

import org.apache.commons.lang3.RandomUtils;

import java.net.InetAddress;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.stream.Collectors;
import java.util.stream.IntStream;

public class OrderGen2Test {

    /** 订单号生成 **/
    private static ZoneId ZONE_ID = ZoneId.of("Asia/Shanghai");
    private static final AtomicInteger SEQ = new AtomicInteger(1000);
    private static final DateTimeFormatter DF_FMT_PREFIX = DateTimeFormatter.ofPattern("yyMMddHHmmssSS");
    public static String generateOrderNo(){
        LocalDateTime dataTime = LocalDateTime.now(ZONE_ID);
        if(SEQ.intValue()>9990){
            SEQ.getAndSet(1000);
        }
        return  dataTime.format(DF_FMT_PREFIX)+ getLocalIpSuffix()+SEQ.getAndIncrement();
    }

    private volatile static String IP_SUFFIX = null;
    private static String getLocalIpSuffix (){
        if(null != IP_SUFFIX){
            return IP_SUFFIX;
        }
        try {
            synchronized (OrderGen2Test.class){
                if(null != IP_SUFFIX){
                    return IP_SUFFIX;
                }
                InetAddress addr = InetAddress.getLocalHost();
                //  172.17.0.4  172.17.0.199 ,
                String hostAddress = addr.getHostAddress();
                if (null != hostAddress && hostAddress.length() > 4) {
                    String ipSuffix = hostAddress.trim().split("\\.")[3];
                    if (ipSuffix.length() == 2) {
                        IP_SUFFIX = ipSuffix;
                        return IP_SUFFIX;
                    }
                    ipSuffix = "0" + ipSuffix;
                    IP_SUFFIX = ipSuffix.substring(ipSuffix.length() - 2);
                    return IP_SUFFIX;
                }
                IP_SUFFIX = RandomUtils.nextInt(10, 20) + "";
                return IP_SUFFIX;
            }
        }catch (Exception e){
            System.out.println("获取IP失败:"+e.getMessage());
            IP_SUFFIX =  RandomUtils.nextInt(10,20)+"";
            return IP_SUFFIX;
        }
    }


    public static void main(String[] args) {
        List<String> orderNos = Collections.synchronizedList(new ArrayList<String>());
        IntStream.range(0,8000).parallel().forEach(i->{
            orderNos.add(generateOrderNo());
        });

        List<String> filterOrderNos = orderNos.stream().distinct().collect(Collectors.toList());

        System.out.println("订单样例："+ orderNos.get(22));
        System.out.println("生成订单数："+orderNos.size());
        System.out.println("过滤重复后订单数："+filterOrderNos.size());
        System.out.println("重复订单数："+(orderNos.size()-filterOrderNos.size()));
    }
}

/**
  订单样例：20082115575546011022
  生成订单数：8000
  过滤重复后订单数：8000
  重复订单数：0
**/

```

\[最后] 代码说明及几点建议
 + generateOrderNo()方法内不需要加锁，因为AtomicInteger内使用的是CAS自旋转锁(保证可见性的同时也保证原子性,具体的请自行了解)
 + getLocalIpSuffix()方法内不需要对不为null的逻辑加同步锁(双向校验锁，整体是一种安全的单例模式)
 + 本人实现的方式并不是解决问题的唯一方式，具体解决问题需要视当前系统架构具体而论
 + 任何测试都是必要的，我同事在前几次尝试解决这个问题后都没有自测，不测试有损开发专业性！','5','王二','374','1','0','2021-03-04 11:10:08.330533','2019-12-01 12:51:52.374003'),
	 (1007,'技术','
jdk8 stream闪亮登场','###  Stream闪亮登场 

####  一. Stream(流)是什么，干什么
  ```
    Stream是一类用于替代对集合操作的工具类+Lambda式编程，他可以替代现有的遍历、过滤、求和、求最值、排序、转换等
  ```

#### 二. Stream操作方式
+  并行方式parallelStream
+  顺序方式Stream

#### 三. Stream优势
+  Lambda 可有效减少冗余代码，减少开发工作量
+  内置对集合List、Map的多种操作方式，含基本数据类型处理
+  并行Stream有效率优势(内置多线程)

#### 四. Stream(流)的基本使用
+  遍历forEach
```
    @Test
    public void stream() {
        //操作List
        List<Map<String, String>> mapList = new ArrayList() {
            {
                Map<String, String> m = new HashMap();
                m.put("a", "1");
                Map<String, String> m2 = new HashMap();
                m2.put("b", "2");
                add(m);
                add(m2);
            }
        };
        mapList.stream().forEach(item-> System.out.println(item));

        //操作Map
        Map<String,Object> mp = new HashMap(){
            {
                put("a","1");
                put("b","2");
                put("c","3");
                put("d","4");
            }
        };
        mp.keySet().stream().forEachOrdered(item-> System.out.println(mp.get(item)));
    }
```
+  过滤filter
  ```
            List<Integer> mapList = new ArrayList() {
            {
                add(1);
                add(10);
                add(12);
                add(33);
                add(99);
            }
        };
       //mapList.stream().forEach(item-> System.out.println(item));
        mapList = mapList.stream().filter(item->{
            return item>30;
        }).collect(Collectors.toList());
        System.out.println(mapList);
  ```
+ 转换map和极值
  ```
      @Test
    public void trans(){
        List<Person> ps = new ArrayList<Person>(){
            {
                Person p1 = new Person();
                p1.setAge(11);
                p1.setName("张强");

                Person p2 = new Person();
                p2.setAge(17);
                p2.setName("李思");

                Person p3 = new Person();
                p3.setAge(20);
                p3.setName("John");

                add(p1);
                add(p2);
                add(p3);
            }
        };
        //取出所有age字段为一个List
        List<Integer> sumAge = ps.stream().map(Person::getAge).collect(Collectors.toList());
        System.out.println(sumAge);
        //取出age最大的那
        Integer maxAge =sumAge.stream().max(Integer::compare).get();
        System.out.println(maxAge);
    }

    class Person{

    private String name;
    private Integer age;

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public Integer getAge() {
        return age;
    }

    public void setAge(Integer age) {
        this.age = age;
    }
 }
  ```
####  五. Stream(流)的效率
+ 模拟非耗时简单业务逻辑
```
    class Person{
    private String name;
    private int age;
    private Date joinDate;
    private String label;

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public int getAge() {
        return age;
    }

    public void setAge(int age) {
        this.age = age;
    }

    public Date getJoinDate() {
        return joinDate;
    }

    public void setJoinDate(Date joinDate) {
        this.joinDate = joinDate;
    }

    public String getLabel() {
        return label;
    }

    public void setLabel(String label) {
        this.label = label;
    }
public class DataLoopTest {
    private static final Logger LOG= LoggerFactory.getLogger(DataLoopTest.class);

    private static final List<Person> persons = new ArrayList<>();
    static {
        for(int i=0;i<=1000000;i++){
            Person p = new Person();
            p.setAge(i);
            p.setName("zhangSan");
            p.setJoinDate(new Date());
            persons.add(p);
        }
    }

    /**
     * for 循环耗时 ===> 1.988
     * for 循环耗时 ===> 2.198
     * for 循环耗时 ===> 1.978
     *
     */
    @Test
    public void forTest(){
        Instant date_start = Instant.now();
        int personSize = persons.size();
        for(int i=0;i<personSize;i++){
            persons.get(i).setLabel(persons.get(i).getName().concat("-"+persons.get(i).getAge()).concat("-"+persons.get(i).getJoinDate().getTime()));
        }
        Instant date_end = Instant.now();
        LOG.info("for 循环耗时 ===> {}", Duration.between(date_start,date_end).toMillis()/1000.0);
    }

    /**
     *  forEach 循环耗时 ===> 1.607
     *  forEach 循环耗时 ===> 2.242
     *  forEach 循环耗时 ===> 1.875
     */
    @Test
    public void forEach(){
        Instant date_start = Instant.now();
        for(Person p:persons){
            p.setLabel(p.getName().concat("-"+p.getAge()).concat("-"+p.getJoinDate().getTime()));
        }
        Instant date_end = Instant.now();
        LOG.info("forEach 循环耗时 ===> {}", Duration.between(date_start,date_end).toMillis()/1000.0);
    }

    /**
     *  streamForeach 循环耗时 ===> 1.972
     *  streamForeach 循环耗时 ===> 1.969
     *  streamForeach 循环耗时 ===> 2.125
     */
    @Test
    public void streamForeach(){
        Instant date_start = Instant.now();
        persons.stream().forEach(p->p.setLabel(p.getName().concat("-"+p.getAge()).concat("-"+p.getJoinDate().getTime())));
        Instant date_end = Instant.now();
        LOG.info("streamForeach 循环耗时 ===> {}", Duration.between(date_start,date_end).toMillis()/1000.0);
    }

    /**
     *  parallelStreamForeach 循环耗时 ===> 1.897
     *  parallelStreamForeach 循环耗时 ===> 1.942
     *  parallelStreamForeach 循环耗时 ===> 1.642
     */
    @Test
    public void parallelStreamForeach(){
        Instant date_start = Instant.now();
        persons.parallelStream().forEach(p->p.setLabel(p.getName().concat("-"+p.getAge()).concat("-"+p.getJoinDate().getTime())));
        Instant date_end = Instant.now();
        LOG.info("parallelStreamForeach 循环耗时 ===> {}", Duration.between(date_start,date_end).toMillis()/1000.0);
    }

}
```
+  模拟耗时简单业务逻辑
```
  public class DataLoopBlockTest {
    private static final Logger LOG= LoggerFactory.getLogger(DataLoopTest.class);

    private static final List<Person> persons = new ArrayList<>();
    static {
        for(int i=0;i<=100000;i++){
            Person p = new Person();
            p.setAge(i);
            p.setName("zhangSan");
            p.setJoinDate(new Date());
            persons.add(p);
        }
    }

    /**
     * for 循环耗时 ===> 101.385
     * for 循环耗时 ===> 102.161
     * for 循环耗时 ===> 101.472
     *
     */
    @Test
    public void forTest(){
        Instant date_start = Instant.now();
        int personSize = persons.size();
        for(int i=0;i<personSize;i++){
            try {
                Thread.sleep(1);
                persons.get(i).setLabel(persons.get(i).getName().concat("-"+persons.get(i).getAge()).concat("-"+persons.get(i).getJoinDate().getTime()));
            }catch (Exception e){
                e.printStackTrace();
            }
        }
        Instant date_end = Instant.now();
        LOG.info("for 循环耗时 ===> {}", Duration.between(date_start,date_end).toMillis()/1000.0);
    }

    /**
     *  forEach 循环耗时 ===> 101.027
     *  forEach 循环耗时 ===> 102.488
     *  forEach 循环耗时 ===> 101.608
     */
    @Test
    public void forEach(){
        Instant date_start = Instant.now();
        for(Person p:persons){
            try {
                Thread.sleep(1);
                p.setLabel(p.getName().concat("-"+p.getAge()).concat("-"+p.getJoinDate().getTime()));
            }catch (Exception e){
                e.printStackTrace();
            }
        }
        Instant date_end = Instant.now();
        LOG.info("forEach 循环耗时 ===> {}", Duration.between(date_start,date_end).toMillis()/1000.0);
    }

    /**
     *  streamForeach 循环耗时 ===> 103.246
     *  streamForeach 循环耗时 ===> 101.128
     *  streamForeach 循环耗时 ===> 102.615
     */
    @Test
    public void streamForeach(){
        Instant date_start = Instant.now();
        //persons.stream().forEach(p->p.setLabel(p.getName().concat("-"+p.getAge()).concat("-"+p.getJoinDate().getTime())));
        persons.stream().forEach(p->{
            try {
                Thread.sleep(1);
                p.setLabel(p.getName().concat("-"+p.getAge()).concat("-"+p.getJoinDate().getTime()));
            }catch (Exception e){
                e.printStackTrace();
            }
        });
        Instant date_end = Instant.now();
        LOG.info("streamForeach 循环耗时 ===> {}", Duration.between(date_start,date_end).toMillis()/1000.0);
    }

    /**
     *  parallelStreamForeach 循环耗时 ===> 51.391
     *  parallelStreamForeach 循环耗时 ===> 53.509
     *   parallelStreamForeach 循环耗时 ===> 50.831
     */
    @Test
    public void parallelStreamForeach(){
        Instant date_start = Instant.now();
        //persons.parallelStream().forEach(p->p.setLabel(p.getName().concat("-"+p.getAge()).concat("-"+p.getJoinDate().getTime())));
        persons.parallelStream().forEach(p->{
            try {
                Thread.sleep(1);
                p.setLabel(p.getName().concat("-"+p.getAge()).concat("-"+p.getJoinDate().getTime()));
            }catch (Exception e){
                e.printStackTrace();
            }
        });
        Instant date_end = Instant.now();
        LOG.info("parallelStreamForeach 循环耗时 ===> {}", Duration.between(date_start,date_end).toMillis()/1000.0);
        //LOG.info("\r\n===> {}",JSON.toJSONString(persons.get(10000)));
    }
}
```
```
   可以看到在<s>百万数据</s>下做简单数据循环处理，对于普通for(for\foreach)循环或stream(并行、非并行)下，几者的效率差异并不明显，
   注意: 在百万数据下，普通for、foreach循环处理可能比stream的方式快许多，对于这点效率的损耗，其实lambda表达式对代码的简化更大！
   另外,在并行流的循环下速度提升了一倍之多，当单个循环耗时较多时，会拉大与前几者的循环效率
    (以上测试仅对于循环而言，其他类型业务处理,比如排序、求和、最大值等未做测试，个人猜测与以上测试结果相似)
```
#### 六. Stream(流)注意项
+ 并行stream不是线程安全的，当对循坏外部统一对象进行读写时候会造成意想不到的错误，这需要留意
+ 因stream总是惰性的，原对象是不可以被修改的，在集合处理完成后需要将处理结果放入一个新的集合容器内
+ 普通循环与stream(非并行)循环，在处理处理数据量比较大的时候效率是一致的，推荐使用stream的形式
+ 对于List删除操作，目前只提供了removeIf方法来实现，并不能使用并行方式
+ 对于lambda表达式的写法
-  当表达式内只有一个返回boolean类型的语句时候语句是可以简写的，例如：
```
 persons.parallelStream().forEach(p->p.setLabel(p.getName().concat("-"+p.getAge()).concat("-"+p.getJoinDate().getTime())));

```
- 当表达式内会有一些复杂处理逻辑时需要加上大括号，这与初始化List参数方式大致一致
```
        persons.parallelStream().forEach(p->{
            try {
                Thread.sleep(1);
                p.setLabel(p.getName().concat("-"+p.getAge()).concat("-"+p.getJoinDate().getTime()));
            }catch (Exception e){
                e.printStackTrace();
            }
        });
```
#### 七. stream&Lambda表达式常用api方法
+  流到流之间的转换类
    -  filter(过滤)
    - map(映射转换)
    - mapTo[Int|Long|Double] (到基本类型流的转换)
    - flatMap(流展开合并)
    - flatMapTo[Int|Long|Double]
    - sorted(排序)
    - distinct(不重复值)
    - peek(执行某种操作，流不变，可用于调试)
    - limit(限制到指定元素数量)
    - skip(跳过若干元素) 

+  流到终值的转换类
    - toArray（转为数组）
    - reduce（推导结果）
    - collect（聚合结果）
    - min(最小值)
    - max(最大值)
    - count (元素个数)
    - anyMatch (任一匹配)
    - allMatch(所有都匹配)
    - noneMatch(一个都不匹配)
    - findFirst（选择首元素）
    - findAny(任选一元素)

+ 直接遍历类
    - forEach (不保证顺序遍历，比如并行流)
    - forEachOrdered（顺序遍历)

+ 构造流类
    - empty (构造空流)
    - of (单个元素的流及多元素顺序流)
    - iterate (无限长度的有序顺序流)
    - generate (将数据提供器转换成无限非有序的顺序流)
    - concat (流的连接)
    - Builder (用于构造流的Builder对象)','1','猪猪不可爱','0','2','2','2021-04-19 09:47:20.905428','2021-04-19 09:47:20.905428'),
	 (1005,'技术','开源后台系统*mee-admin*','
### **mee-admin**开源后台系统

#### Preface

```
  这是一个开放的时代，我们不能总是把东西揣在口袋里面自己乐呵。
  也正如名言所说的“如果你有两块面包，你当用其中一块去换一朵水仙花”
  所以，继上一次把我的两个个人项目开源之后今天我再一次把自有的后台页面也开源出来，以回馈整个开源世界。
```
#### 开源地址

  [https://github.com/funnyzpc/mee-admin](https://github.com/funnyzpc/mee-admin)

#### 项目结构概述

  mee-admin是由我的个人`mee`项目开源而来,`mee-admin`项目是一个前后端一体化的项目,不过在代码上实现了页面与数据分离，是一个非常好的
  轻量级后端工程，所以在正式使用时您会发现主体业务部门均是采用json交互，前端页面使用模板工具实现数据展现及编辑
  与`jeesite`不一样，我们不使用`jsp+sitmesh+ehcache`臃肿化项目
  与`Spring-Cloud-Platform` `xboot` 不一样,这里不使用`vue` `iview` 做前后端分离，也不使用`springclooud`做集群分布式
  所以我的项目更加轻量级，不需要装`node` 不需要`npm`打包 需不要安装`nginx` 同时也不需要编写无聊的mapper接口，不需要单独写增删改....
  所以对于企业内部需求开发更是无比的急速
  同时，`mee-admin`只需具有`java`后端以及一点点`javascript`开发能力，便可急速上手。

#### 项目技术相关

+ 使用`springboot 2.3.4.RELEASE`作为基础框架
+ 使用`mybatis`作为`dao`框架
+ 使用`postgreSQL` 作为框架DB(可支持`Mysql`及`Oracle`)
+ 使用`shiro`做权限管理
+ 使用`Freemarker`做页面模板
+ 使用`jquery` 插件作`javascript`基本扩展库使用
  - 目前只是一些组件依赖用,建议大多数情况下使用`ES5`或`ES6`规范的`javascript`扩展
+ 使用`handlebars`做表单及数据模板
+ 使用`seajs` 做基础模块管理
+ 封装了序列(`ID`)生成器(支持分布式)
    - `SeqGenServiceImpl` 序列生成器(支持分布式)
    - `SeqGenUtil` 普通序列生成器
+ 封装了`Jackson`的`json`库，完全可替代`fastjson`
+ 封装了物理分页`PhysicalPageInterceptor`及逻辑分页`LogicalPageIntercepter`(两个可任选其一)，完全替代`RowBounds`及一众分页依赖
+ 封装了`Excel`及`CSV`工具
  - `ExcelReadUtil` EXCEL读工具
  - `ExcelWriteUtil` EXCEL写工具
  - `CSVUtils` CSV读工具
+ 简单封装了java8日期工具类 `DateUtil`

#### 项目界面
+ **登录**
  ![](https://img2020.cnblogs.com/blog/1161789/202010/1161789-20201007163723653-1458822817.png)


+ **主页**
  ![](https://img2020.cnblogs.com/blog/1161789/202010/1161789-20201007163732285-1162302769.png)


+ **报表**
  ![](https://img2020.cnblogs.com/blog/1161789/202010/1161789-20201007163740366-610927997.png)


+ **基础配置**
  ![](https://img2020.cnblogs.com/blog/1161789/202010/1161789-20201007163748704-551106189.png)


+ **编辑及修改**
  ![](https://img2020.cnblogs.com/blog/1161789/202010/1161789-20201007163756723-1520708103.png)


+ **系统配置**
  ![](https://img2020.cnblogs.com/blog/1161789/202010/1161789-20201007163804777-933345699.png)



#### 项目运行及打包
+ 本地项目运行 
  - Fork `mee-admin`
  - git clone `mee-admin` to local
  - init DB table []()
  - use Idea IDE open project 
  - auto build dependency
  - Idea start config
    - run `MeeApplication` and program arguments add `--spring.profiles.active=dev`
    - 注[dev、test、prod均为pom.xml下配置的环境参数](#)
  
+ 打包及Linux服务器构建脚本,见[mee-admin](https://github.com/funnyzpc/mee-admin)
    - 必须安装maven(方法请自行搜索引擎查找)
    
#### 项目访问
+ local: `http://127.0.0.1/mee/login`
+ server: `http://[Your DOMAIN or HOST+PORT]/mee/login`

#### Notice
 
 虽整个项目封装的较为完整, 但是对于一些自定义的展示还是需要有一定的前端技能
 作为补偿，这里大致写了功能开发流程[see:Function flow](#### Function flow),具体的还需要读者具体学习哈~

#### Function flow
+ 功能开发流程
    - 添加mybatis SQL xml文件及映射实体类entity
    - 编写控制器controller及业务service代码
    - 编写构建前端页面并添加菜单项
    - 添加依赖js `resources/public/module` 下
    - 后端添加权限标识`@RequiresPermissions("your_auth_code")`
    - 前端(菜单和业务页面)添加权限标识`<@shiro.hasPermission name="your_auth_code"></@shiro.hasPermission>`
    - 后台添加菜单项目
    - 后台角色权限分配

+ js添加对话框或按钮扩展功能([这是难点!](#))
``` 
       业务前端js采用模块化依赖并封装了表单著录以及增删改查相应功能，十分便捷，
    目前对于扩展功能(比如添加一个’重算‘) 需要自定义函数及相应逻辑，具体流程大致如下
```

  1. 在[search-form](#)内定义button控件(一定要有name属性)
  2. 在依赖的js文件内的init函数内定义扩展`toolbar:{ "控件属性名": 属性名对应函数 }`
  3. 编写相应函数逻辑
  
 
 #### end
   
   欢迎提交issue，如有好的建议及意也请留下脚印，这里先感谢哈😁
   同时, 如有困难可以咨询 `funnyzpc@gmail.com`','1','不吃鱼的猫','0','2','2','2021-03-04 20:42:53.8851','2021-03-04 20:42:53.8851'),
	 (1003,'技术','go web& 二维码& 打包部署','### go语言简易web应用 & 二维码生成及解码 & 打包部署

转载请注明出处: [https://www.cnblogs.com/funnyzpc/p/10801476.html](https://www.cnblogs.com/funnyzpc/p/10801476.html)

#### 前言(闲扯)
```
(20190503)我知道今天会有其他活动，因此我提前买了杯咖啡，
(20190504)我知道深夜会完不成博客,  因此我加班到了这个点。
首先需要做的事情，Demo 准备并调试
还需要做的事情，构建github项目
以及要做的事情，README文档编写
最后要做的事情，生成一篇博客
```

#### 简单WEB应用
话说一个简单的WEB应用需要多少行依赖，多少行代码，运行需要多大的package,需要多大的运行环境？
+ 对于java：
    - 我需要构建下面这些包(5MB+)
    ```
          01） aopalliance-1.0.jar                aop的工具包                 `
          02） commons-logging-1.1.3.jar          commons的日志管理
          03） spring-aop-3.2.8.RELEASE.jar       Spring的切面编程
          04） spring-beans-3.2.8.RELEASE.jar     SpringIoC(依赖注入)的基础实现
          05） spring-context-3.2.8.RELEASE.jar   Spring提供在基础IoC功能上的扩展服务
          06） spring-core-3.2.8.RELEASE.jar      Spring的核心包
          07） spring-expression-3.2.8.RELEASE.jar  Spring表达式语言
          08） spring-web-3.2.8.RELEASE.jar         SpringWeb下的工具包
          09） spring-webmvc-3.2.8.RELEASE.jar      SpringMVC工具包
          10） jstl-1.1.2.jar                       JSP标准标签库
    ```
    - 需要编写以下代码(14行+)
    ```
          package com.test.controller;
          import org.springframework.stereotype.Controller;
          import org.springframework.ui.Model;
          import org.springframework.web.bind.annotation.RequestMapping;
          import org.springframework.web.bind.annotation.RequestMethod;

          @Controller
          @RequestMapping(value="/hello")
          public class HelloController {
              @RequestMapping(value="/world",method=RequestMethod.GET)
              public String hello(Model model){
                  model.addAttribute("msg", "你好spring mvc");
                  return "index";
              }
          }
    ```
    - 打包(jar or war 5MB+)
    - 部署和环境(jdk 100MB+ , tomcat 5MB+ total：105MB+)
+ 对于Go
    - 需要代码(15行+)
    ```
    package main

    import (
    	"fmt"
    	"log"
    	"net/http"
    )

    func main() {
    	http.HandleFunc("/", index)
    	log.Println("请访问:", "http://127.0.0.1:2222")
    	http.ListenAndServe(":2222", nil)
    }

    func index(w http.ResponseWriter, r *http.Request) {
    	fmt.Printf("[%s|%s] -> http://%s%s \n", r.Method, r.Proto, r.Host, r.RequestURI)
    	dateTime := time.Now().Format("2006-01-02 15:04:05")
    }
    ```
    - 打包(<6MB,upx加壳<2MB)
    - 部署和环境(<6MB or <2MB)

结论：一个java web应用部署不小于100MB，而一个go web应用最少只需要2MB，你真的没听错他真的很小而且迅速，唯一不能比的是
java的生态 太庞大了，这是java之所以存在的优势，不过这终将成为历史。

(以上 go 代码在这里：[simpleServer.go](https://github.com/funnyzpc/go-project-example/blob/master/src/qrCodes/simpleServer.go))

#### 二维码生成及解码

 二维码简称(QR CODE),中文全名叫快速响应码，他的基础基础包含：向量运算、字符编码、图形识别等，需要具体了解的可涉猎此
 [二维码原理](https://www.cnblogs.com/alantu2018/p/8504373.html)，这里不再从算法底层开始写起(毕竟大多数人都不会哈)，
 主要用到了开源都两个依赖(编码和解码)

+ 二维码生成

  这里用到了[go-qrcode](https://github.com/skip2/go-qrcode)

 - Demo主要逻辑(已调试通过)
 ```
    // 写二维码
    func writeQrCode() {
    	// 写二维码
    	err := qrcode.WriteFile("https://funnyzpc.cnblogs.com", qrcode.Medium, 256, "D:/tmp/cnblogs.png")
    	if err != nil {
    		fmt.Println(err)
    	}
    }
 ```

+ 二维码解码

  这里用到了[qrcode](https://github.com/tuotoo/qrcode)

    - Demo主要逻辑
    ```
    func ReadQrCode(){
        //获取上传的第一个文件
        file, _, _ := os.Open("本地文件路径")
        // 读取文件
        qrmatrix, err := rQrCode.Decode(file)
        defer file.Close()
        if err != nil {
            fmt.Println(err.Error())
            return
        }
        log.Println("获取到二维码内容：", qrmatrix.Content)
    }
    ```

#### 二维码解析+WEB服务

一个产品的终态必将是一些列技术的组合，比如搭建一个在线的二维码解析应用。

+ 参考代码
  ```
    func main() {
        http.HandleFunc("/", IndexAction)
        http.HandleFunc("/qrCode", ReadQrCode)
        log.Println("请打开页面: http://127.0.0.1:2345")
        http.ListenAndServe(":2345", nil)
    }

    // 主页
    func IndexAction(writer http.ResponseWriter, request *http.Request) {
        t, err := template.ParseFiles("template/page/index.html")
        if err != nil {
            log.Println(err)
        }
        t.Execute(writer, nil)
    }

    type QrCode struct {
        QrContent string
    }

    // 读取二维码
    func ReadQrCode(writer http.ResponseWriter, request *http.Request) {
        //判断请求方式
        if request.Method == "POST" {
            //设置内存大小
            request.ParseMultipartForm(64 << 20)
            //获取上传的第一个文件
            file, _, _ := request.FormFile("qrFile")
            // 读取文件
            qrmatrix, err := rQrCode.Decode(file)
            defer file.Close()
            if err != nil {
                fmt.Println(err.Error())
                return
            }
            log.Println("获取到二维码内容：", qrmatrix.Content)

            t, err := template.ParseFiles("template/page/qrCode.html")
            if err != nil {
                log.Println(err)
            }
            t.Execute(writer, QrCode{QrContent: qrmatrix.Content})
        } else {
            //解析模板文件
            t, _ := template.ParseFiles("template/page/qrCode.html")
            //输出文件数据
            t.Execute(writer, nil)
        }
    }


    // 读二维码
    func readQrCode() {
        file, error := os.Open("D:/tmp/cnblogs.png")
        if error != nil {
            fmt.Println(error.Error())
            return
        }
        defer file.Close()
        qrmatrix, err := rQrCode.Decode(file)
        if err != nil {
            fmt.Println(err.Error())
            return
        }
        fmt.Println(qrmatrix.Content)
    }
  ```

+ 最终效果图

    - 主页
    ![](https://img2018.cnblogs.com/blog/1161789/201905/1161789-20190504060247747-16554739.jpg)

    - 结果
    ![](https://img2018.cnblogs.com/blog/1161789/201905/1161789-20190504060258415-1356150150.jpg)

#### 打包部署

 对于部署，在前面java和go的对比中已经提到过，go 应用不存在虚拟机，他的代码是直接从文本编译成二进制包(包含运行环境) 最终也必然是轻巧无依赖的，
 另外，需要说的是go 的 打包本身是不加壳的，源包会比较大，一般部署时会做两个处理。

+ 使用 `-ldflags` 去掉符号 去掉调试 压缩体积

+ 同时使用upx加壳 `upx --backup --brute [PACKAGE_FILE_NAME]` 以进一步压缩体积(压缩至1/3),加密软件包，这样利于传输发布同时还能保持原生包的功效哦～

这里我简要给出一般的打包命令：
```
linux `GOOS=linux GOARCH=amd64 go build -ldflags "-w -s" ./main.go`
window `GOOS=windows GOARCH=amd64 go build -ldflags "-w -s" ./main.go`
mac `GOOS=darwin GOARCH=amd64 go build -ldflags "-w -s" ./main.go`
```

引用加壳命令：
```
upx --backup --brute [main.exe(windows) or main(linux、mac)]

```

最后上线部署：
```
    linux: ./[PACKAGE_FILE] &
    mac: ./[PACKAGE_FILE] &
    windows: 双击[PACKAGE_FILE.exe],或将[PACKAGE_FILE.exe]配置为服务
```

#### 最后

 以上所有代码均在我的github项目中，若所言有误恳请指正～

 项目地址：[qrCodes](https://github.com/funnyzpc/go-project-example/tree/master/src/qrCodes)','1','不吃鱼的猫','0','2','2','2021-03-04 20:42:42.133476','2021-03-04 20:42:42.133476');