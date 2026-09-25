(function(){
  const c=window.VANIDAXI_CONFIG||window.VaniDaxiConfig||{};
  const base=(c.SUPABASE_URL||c.supabaseUrl||'').replace(/\/$/,'');
  const key=c.SUPABASE_PUBLISHABLE_KEY||c.supabasePublishableKey||'';
  const storeKey='vani_session_daxi';
  const pkceVerifierKey='vani_pkce_verifier';
  const pkceFlowKey='vani_pkce_flow';
  function session(){try{return JSON.parse(localStorage.getItem(storeKey)||'null')}catch(_){return null}}
  function save(s){if(s)localStorage.setItem(storeKey,JSON.stringify(s));else localStorage.removeItem(storeKey)}
  function requireConfig(){if(!base||!key)throw new Error('La conexión de VaniDaxi todavía no está configurada.')}
  function cleanAuthUrl(){try{const u=new URL(location.href);['code','error','error_description','error_code','state','type'].forEach(k=>u.searchParams.delete(k));u.hash='';history.replaceState({},document.title,u.pathname+(u.searchParams.toString()?'?'+u.searchParams.toString():''))}catch(_){}}
  function b64url(bytes){let s='';for(let i=0;i<bytes.length;i++)s+=String.fromCharCode(bytes[i]);return btoa(s).replace(/\+/g,'-').replace(/\//g,'_').replace(/=+$/,'')}
  async function createPkce(flow){
    if(!globalThis.crypto?.getRandomValues||!globalThis.crypto?.subtle) return null;
    const bytes=new Uint8Array(32);crypto.getRandomValues(bytes);
    const verifier=b64url(bytes);
    const digest=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(verifier));
    const challenge=b64url(new Uint8Array(digest));
    sessionStorage.setItem(pkceVerifierKey,verifier);
    sessionStorage.setItem(pkceFlowKey,flow||'signed_in');
    return challenge;
  }
  async function request(path,options={},retry=true){
    requireConfig();
    const s=session(),headers=Object.assign({'apikey':key,'Content-Type':'application/json'},options.headers||{});
    if(s&&s.access_token)headers.Authorization='Bearer '+s.access_token;
    let r;
    try{r=await fetch(base+path,Object.assign({},options,{headers}))}
    catch(e){throw new Error('No se pudo conectar con VaniDaxi. Comprueba tu conexión a internet.')}
    if(r.status===401&&retry&&s&&s.refresh_token){
      try{
        const rr=await fetch(base+'/auth/v1/token?grant_type=refresh_token',{method:'POST',headers:{apikey:key,'Content-Type':'application/json'},body:JSON.stringify({refresh_token:s.refresh_token})});
        if(rr.ok){const ns=await rr.json();save(ns);return request(path,options,false)}
      }catch(_){}
    }
    const body=await r.text();let data=body;try{data=body?JSON.parse(body):null}catch(_){}
    if(!r.ok)throw new Error(data&&data.msg?data.msg:data&&data.message?data.message:body||('HTTP '+r.status));
    return data;
  }
  async function signIn(email,password){const d=await request('/auth/v1/token?grant_type=password',{method:'POST',body:JSON.stringify({email,password})},false);save(d);return d}
  async function signUp(email,password,meta){
    const challenge=await createPkce('signup');
    const body={email,password,data:meta||{}};
    if(challenge){body.code_challenge=challenge;body.code_challenge_method='s256'}
    const d=await request('/auth/v1/signup',{method:'POST',body:JSON.stringify(body)},false);
    if(d.access_token){save(d);sessionStorage.removeItem(pkceVerifierKey);sessionStorage.removeItem(pkceFlowKey)}
    return d;
  }
  async function sendOtp(phone,meta){return request('/auth/v1/otp',{method:'POST',body:JSON.stringify({phone,create_user:true,data:meta||{}})},false)}
  async function verifyOtp(phone,token){const d=await request('/auth/v1/verify',{method:'POST',body:JSON.stringify({phone,token,type:'sms'})},false);if(d.access_token)save(d);return d}
  async function recoverPassword(email,redirectTo){
    const challenge=await createPkce('recovery');
    const body={email,options:redirectTo?{redirectTo}:undefined};
    if(challenge){body.code_challenge=challenge;body.code_challenge_method='s256'}
    return request('/auth/v1/recover',{method:'POST',body},false);
  }
  async function updatePassword(password){return request('/auth/v1/user',{method:'PUT',body:JSON.stringify({password})})}
  async function consumeAuthHash(){
    try{
      requireConfig();
      const q=new URLSearchParams(location.search);
      if(q.get('error')){const msg=q.get('error_description')||q.get('error');cleanAuthUrl();return {type:'error',message:msg}}
      const code=q.get('code');
      if(code){
        const verifier=sessionStorage.getItem(pkceVerifierKey);
        const flow=sessionStorage.getItem(pkceFlowKey)||'signed_in';
        if(!verifier){cleanAuthUrl();return {type:'error',message:'No se encontró la verificación segura de esta sesión. Inicia el acceso nuevamente.'}}
        try{
          const d=await request('/auth/v1/token?grant_type=pkce',{method:'POST',body:JSON.stringify({auth_code:code,code_verifier:verifier})},false);
          if(!d.access_token){cleanAuthUrl();return {type:'error',message:'La autenticación no devolvió una sesión válida.'}}
          save(d);sessionStorage.removeItem(pkceVerifierKey);sessionStorage.removeItem(pkceFlowKey);cleanAuthUrl();
          return {type:flow};
        }catch(e){sessionStorage.removeItem(pkceVerifierKey);sessionStorage.removeItem(pkceFlowKey);cleanAuthUrl();return {type:'error',message:e.message||'No se pudo completar la autenticación.'}}
      }
      const raw=(location.hash||'').replace(/^#/,'').replace(/^\?/,'').replace(/&amp;/g,'&');
      if(!raw)return null;
      const p=new URLSearchParams(raw);
      if(p.get('error')){const msg=p.get('error_description')||p.get('error');cleanAuthUrl();return {type:'error',message:msg}}
      if(p.get('access_token')&&p.get('refresh_token')){
        save({access_token:p.get('access_token'),refresh_token:p.get('refresh_token'),expires_in:Number(p.get('expires_in')||3600),token_type:p.get('token_type')||'bearer'});
        sessionStorage.removeItem(pkceVerifierKey);sessionStorage.removeItem(pkceFlowKey);cleanAuthUrl();
        return {type:p.get('type')||'signed_in'};
      }
      return null;
    }catch(e){return {type:'error',message:e.message||'No se pudo procesar la autenticación.'}}
  }
  async function me(){const s=session();if(!s?.access_token)return null;try{return await request('/auth/v1/user')}catch(_){return null}}
  const qp=(filters={})=>Object.entries(filters).map(([k,v])=>Array.isArray(v)?encodeURIComponent(k)+'=in.('+v.map(x=>String(x)).join(',')+')':v===null?encodeURIComponent(k)+'=is.null':encodeURIComponent(k)+'='+encodeURIComponent(String(v))).join('&');
  const table={
    list:(name,select='*',filters={},extra='')=>request('/rest/v1/'+name+'?select='+encodeURIComponent(select)+(Object.keys(filters).length?'&'+qp(filters):'')+(extra?'&'+extra:'')),
    one:(name,select='*',filters={})=>request('/rest/v1/'+name+'?select='+encodeURIComponent(select)+'&'+qp(filters)+'&limit=1'),
    insert:(name,row,prefer='return=representation')=>request('/rest/v1/'+name,{method:'POST',headers:{Prefer:prefer},body:JSON.stringify(row)}),
    update:(name,row,filters,prefer='return=representation')=>request('/rest/v1/'+name+'?'+qp(filters),{method:'PATCH',headers:{Prefer:prefer},body:JSON.stringify(row)}),
    remove:(name,filters)=>request('/rest/v1/'+name+'?'+qp(filters),{method:'DELETE',headers:{Prefer:'return=minimal'}})
  };
  async function rpc(name,args={}){return request('/rest/v1/rpc/'+name,{method:'POST',body:JSON.stringify(args)})}
  async function edge(name,method='POST',body=null){const opts={method};if(body!==null)opts.body=JSON.stringify(body);return request('/functions/v1/'+name,opts)}
  async function profile(){const u=await me();if(!u)return null;const rows=await table.list('profiles','id,full_name,username,phone,role,is_active,terms_accepted_at,terms_version',{id:'eq.'+u.id});return rows[0]||null}
  async function oauth(provider){
    const challenge=await createPkce('oauth');
    const redirect=location.href.split('#')[0];
    const params=new URLSearchParams({provider,redirect_to:redirect});
    if(challenge){params.set('code_challenge',challenge);params.set('code_challenge_method','s256')}
    location.href=base+'/auth/v1/authorize?'+params.toString();
  }
  window.VaniCore={config:c,session,save,request,signIn,signUp,sendOtp,verifyOtp,recoverPassword,updatePassword,consumeAuthHash,me,profile,table,rpc,edge,oauth,signOut:()=>save(null)};
})();