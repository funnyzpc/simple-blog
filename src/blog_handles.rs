
use handlebars::Handlebars;
use actix_web::{HttpResponse, web, HttpRequest};
use sqlx::{Pool, Postgres, Row, Error};
use sqlx::postgres::PgRow;
use serde::{Deserialize, Serialize};

// 博客
const BLOG_HTML:&str = r#"<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><title>{{title}}</title><meta name="viewport" content="width=device-width,height=device-height,initial-scale=0.8,user-scalable=yes,minimum-scale=0.6,maximum-scale=2.0"/></head><body style="font-family:雅黑;background-color:#8d8d8d;top:0;left:0;"><div style="width:96%;margin: auto;background-color:#ffefff;border-radius:4px;padding:4px 16px 2px 16px;box-shadow:8px -4px 8px black;min-height:100%;position:absolute;">    {{{content}}}</div></body></html>"#;

#[get("/{id}")]
pub async fn blog(req:HttpRequest,
                  db: web::Data<Pool<Postgres>>,
                  hb: web::Data<Handlebars<'_>>) -> HttpResponse {
    // 检查参数
    let id:i32 = req.match_info().load().unwrap();
    //let (id,name):(i32,String) = req.match_info().load().unwrap();
    //let id:(i32) = info.into_inner();
    // 查询
    let t_blog:TBLOG = sqlx::query("select *,to_char(update_date,'yyyy-MM-dd HH24:mi:ss') as update_date_alias,to_char(create_date,'yyyy-MM-dd HH24:mi:ss') as create_date_alias from t_blog where id=$1")
        .bind(id)
        .map(|item: PgRow| TBLOG {
            id: String::from("1002"),
            subject: item.get("subject"),
            title: item.get("title"),
            content: item.get("content"),
            user_id: item.get("user_id"),
            visited: item.get("visited"),
            type_alias: item.get("type"),
            status: item.get("status"),
            update_date: item.get("update_date_alias"),
            create_date: item.get("create_date_alias"),
            origin: item.get("origin"),
        })
        .fetch_one(db.get_ref())
        .await.expect("--查询博客出错了--");

    // 检查结果(是否查询到)
    if t_blog.id.is_empty(){
        println!("博客ID不存在 {}",id);
        return HttpResponse::NotFound().content_type("text/html").body(String::from("博客未找到。。。"));
    }
    println!("查询到=>id:{},title:{:?},update_date:{:?}",id,t_blog.title,t_blog.update_date);

    // 模板渲染
    let html : String = markdown::to_html(&t_blog.content);
    let title:String = t_blog.title;
    let d = json!({"title":title,"content":&html});
    let body = hb.render_template(BLOG_HTML,&d).unwrap_or(String::from("<p>目标解析失败</p>"));

    // 返回
    HttpResponse::Ok().body(body)
}

// 列表
const BLOG_LIST:&str = r#"<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><title>Blogs</title><meta name="viewpmort" content="width=device-width,height=device-height,initial-scale=0.8,user-scalable=yes,minimum-scale=0.6,maximum-scale=2.0"/><style>    div>p>a{color:#8585ff;}</style></head><body style="font-family: 雅黑;background-color: #8d8d8d;top:0;left:0;"><div style="width:80%;margin:5% auto 2% 10%;background-color:black;border-radius:4px;padding:16px 16px 40px 16px;;color:white;"><h2>博客</h2>{{#each this}}<p><time>{{create_date}} </time><a href="/blog/{{id}}" target="_blank"> {{title}}</a><small><em> {{origin}}</em></small></p>{{/each}}</div></body></html>"#;
#[get("")]
pub async fn list(
    hb: web::Data<Handlebars<'_>>,
    db: web::Data<Pool<Postgres>>
) -> HttpResponse {
    println!("/blog/list => start");
    let t_blogs:Vec<TBLOG> = sqlx::query(
        r#"select '' as subject,'' as content,'' as user_id,'' as visited,'' as update_date_alias,'' as type,'' as status,  id::varchar,title,origin,to_char(create_date,'yyyy-MM-dd HH24:mi:ss') as create_date_alias from t_blog"#)
        .map(|item: PgRow| TBLOG {
            id: item.get("id"),
            subject: item.get("subject"),
            title: item.get("title"),
            content: item.get("content"),
            user_id: item.get("user_id"),
            visited: item.get("visited"),
            type_alias: item.get("type"),
            status: item.get("status"),
            update_date: item.get("update_date_alias"),
            create_date: item.get("create_date_alias"),
            origin: item.get("origin"),
        })
        .fetch_all(db.get_ref())
        .await.expect("--查询博客列表出错了--");

    // 检查结果(是否查询到)
    if t_blogs.len()==0{
        println!("列表数据不存在");
        return HttpResponse::NotFound().content_type("text/html").body(String::from("博客未找到。。。"));
    }

    println!("/blog/list => 准备模板渲染");
    // 模板渲染
    let body = hb.render_template(BLOG_LIST,&t_blogs).unwrap_or(String::from("<p>解析列表失败...</p>"));

    // 返回
    HttpResponse::Ok().body(body)
}

#[derive(Deserialize, Serialize, Debug, Clone)]
pub struct Tmp {
    pub id: String,
    pub name: Option<String>,
}

#[derive(Deserialize, Serialize, Debug, Clone)]
pub struct TBLOG {
    pub id: String,
    pub subject: String,
    pub title: String,
    pub content: String,
    pub user_id: Option<String>,
    pub visited: Option<String>,
    pub type_alias: Option<String>,
    pub status: Option<String>,
    pub update_date: Option<String>,
    //pub update_date: Option<PrimitiveDateTime>,
    pub create_date: Option<String>,
    pub origin: Option<String>,
}

impl<'c> sqlx::FromRow<'c,PgRow> for TBLOG {
    fn from_row(row: &PgRow) -> Result<Self, Error> {
        Ok(TBLOG {
            id: row.get("id"),
            subject: row.get("subject"),
            title: row.get("title"),
            content: row.get("content"),
            user_id: row.get("user_id"),
            visited: row.get("visited"),
            type_alias: row.get("type"),
            status: row.get("status"),
            update_date: row.get("update_date_alias"),
            create_date: row.get("create_date_alias"),
            origin: row.get("origin"),
        })
    }
}