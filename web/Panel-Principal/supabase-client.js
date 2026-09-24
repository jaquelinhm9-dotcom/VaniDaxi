(function(){
  const c=window.VANIDAXI_CONFIG||window.VaniDaxiConfig||{};
  const base=(c.SUPABASE_URL||c.supabaseUrl||'').replace(/\/$/,'');
  const key=c.SUPABASE_PUBLISHABLE_KEY||c.supabasePublishableKey||'';
  const storeKey='vani_session';
  function session(){try{return JSON.parse(localStorage.getItem(storeKey)||'null')}catch(_){return null}}
  function save(s){if(s)localStorage.setItem(storeKey,JSON.stringify(s));else localStorage.removeItem(storeKey)}
  async function request(path,options={},retry=true){
    const s=session(), headers=Object.assign({'apikey':key,'Content-Type':'application/json'},options.headers||{});
    if(s&&s.access_token)headers.Authorization='Bearer '+s.access_token;
    const r=await fetch(base+path,Object.assign({},options,{headers}));
    if(r.status===401&&retry&&s&&s.refresh_token){
      const rr=await fetch(base+'/auth/v1/token?grant_type=refresh_token',{method:'POST',headers:{apikey:key,'Content-Type':'application/json'},body:JSON.stringify({refresh_token:s.refresh_token})});
      if(rr.ok){const ns=await rr.json();save(ns);return request(path,options,false)}
    }
    const text=await r.text();
    let data=text;try{data=text?JSON.parse(text):null}catch(_){}
    if(!r.ok)throw new Error(data&&data.message?data.message:(data&&data.msg?data.msg:text)||('HTTP '+r.status));
    return data;
  }
  const qp=(filters={})=>Object.entries(filters).map(([k,v])=>{
    if(Array.isArray(v))return encodeURIComponent(k)+'=in.('+v.map(x=>String(x)).join(',')+')';
    if(v===null)return encodeURIComponent(k)+'=is.null';
    return encodeURIComponent(k)+'='+encodeURIComponent(String(v));
  }).join('&');
  async function signIn(email,password){const d=await request('/auth/v1/token?grant_type=password',{method:'POST',body:JSON.stringify({email,password})},false);save(d);return d}
  async function signUp(email,password,meta){const d=await request('/auth/v1/signup',{method:'POST',body:JSON.stringify({email,password,data:meta||{}})},false);if(d.access_token)save(d);return d}
  async function recoverPassword(email,redirectTo){return request('/auth/v1/recover',{method:'POST',body:JSON.stringify({email,options:redirectTo?{redirectTo}:undefined})},false)}
  async function updatePassword(password){return request('/auth/v1/user',{method:'PUT',body:JSON.stringify({password})})}
  function consumeRecovery(){try{const p=new URLSearchParams((location.hash||'').replace(/^#/,'').replace(/^\?/,'').replace(/&amp;/g,'&'));if(p.get('type')==='recovery'&&p.get('access_token')){save({access_token:p.get('access_token'),refresh_token:p.get('refresh_token'),expires_in:Number(p.get('expires_in')||3600),token_type:p.get('token_type')||'bearer'});if(history.replaceState)history.replaceState({},document.title,location.pathname+location.search);return true}}catch(_){ }return false}
  async function me(){const s=session();if(!s?.access_token)return null;try{return await request('/auth/v1/user')}catch(_){return null}}
  const table={
    list:(name,select='*',filters={},extra='')=>request('/rest/v1/'+name+'?select='+encodeURIComponent(select)+(Object.keys(filters).length?'&'+qp(filters):'')+(extra?'&'+extra:'')),
    one:(name,select='*',filters={})=>request('/rest/v1/'+name+'?select='+encodeURIComponent(select)+'&'+qp(filters)+'&limit=1'),
    insert:(name,row,prefer='return=representation')=>request('/rest/v1/'+name,{method:'POST',headers:{Prefer:prefer},body:JSON.stringify(row)}),
    update:(name,row,filters,prefer='return=representation')=>request('/rest/v1/'+name+'?'+qp(filters),{method:'PATCH',headers:{Prefer:prefer},body:JSON.stringify(row)}),
    remove:(name,filters)=>request('/rest/v1/'+name+'?'+qp(filters),{method:'DELETE',headers:{Prefer:'return=minimal'}})
  };
  async function rpc(name,args={}){return request('/rest/v1/rpc/'+name,{method:'POST',body:JSON.stringify(args)})}
  async function profile(){const u=await me();if(!u)return null;const rows=await table.list('profiles','id,full_name,username,phone,role,is_active,terms_accepted_at,terms_version',{id:'eq.'+u.id});return rows[0]||null}
  function oauth(provider){const redirect=encodeURIComponent(location.href.split('#')[0]);location.href=base+'/auth/v1/authorize?provider='+encodeURIComponent(provider)+'&redirect_to='+redirect}
  window.VaniCore={config:c,session,save,request,signIn,signUp,me,profile,table,rpc,oauth,signOut:()=>save(null)};
})();