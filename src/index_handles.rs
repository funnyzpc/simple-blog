
use handlebars::Handlebars;
use actix_web::{HttpResponse, web};

const INDEX_HTML:&str = r#"<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewpmort"content="width=device-width,height=device-height,initial-scale=0.8,user-scalable=yes,minimum-scale=0.6,maximum-scale=2.0"/><title>欢迎进入我的博客平台</title></head><body><div style="width:70%;margin-left:15%;"><h2>欢迎进入我的博客平台</h2><p><a href="/blog"target="_blank">我的博客系统</a></p><p><a href="https://www.cnblogs.com/funnyzpc/"target="_blank">博客园博客</a></p><p><a href="https://github.com/funnyzpc/"target="_blank">我的github托管代码</a></p><p><a href="https://gitee.com/funnyzpc"target="_blank">我的gitee托管代码</a></p></div></body></html>"#;

#[get("/")]
pub async fn index(hb: web::Data<Handlebars<'_>>,) -> HttpResponse {
    // println!("===>enter index<===");
    let body = hb.render_template(INDEX_HTML,&"{}").unwrap_or(String::from("<p>目标解析失败</p>"));
    HttpResponse::Ok().content_type("text/html;charset=utf-8").body(body)
}