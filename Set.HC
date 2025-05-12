#ifndef SET_H
#define SET_H "gay frogballer"
class CI64Set {
  I64 cnt,cap;
  I64 *body;
};
U0 I64SetDel(CI64Set *s) {
  Free(s->body);
  Free(s);
}
CI64Set *I64SetNew() {
  CI64Set *s=CAlloc(sizeof(CI64Set),doom_task);
  s->cap=16;
  s->body=CAlloc(16*8,doom_task);
  return s;
}
Bool I64SetHas(CI64Set *s,I64 v) {
  I64 i=0;
  while(i<s->cnt){
    if(s->body[i]==v)
      return TRUE;
    if(s->body[i]>v)
      return FALSE;
    i++;
  }
 return FALSE;
}
Bool I64SetAdd(CI64Set *s,I64 v) {
  I64 *new,idx,idx2;
  if(s->cnt+1>=s->cap) {
     new=CAlloc(MSize(s->body)+16*8,doom_task);
     s->cap+=16;
     MemCpy(new,s->body,s->cnt*8);
     Free(s->body);
     s->body=new;
  }
  for(idx=0;idx!=s->cnt;idx++) {
    if(s->body[idx]==v) {
      return FALSE;
    } else if(s->body[idx]>v) {
      for(idx2=s->cnt;idx2>idx;--idx2)
	s->body[idx2]=s->body[idx2-1];
      s->body[idx]=v;
      s->cnt++;
      return TRUE;
    }
  }
  s->body[s->cnt]=v;
  s->cnt++;
  return TRUE;
}
U0 I64SetRem(CI64Set *s,I64 v) {
  I64 idx,ptr=0,del=0;
  for(idx=0;idx!=s->cnt;idx++) {
    if(s->body[idx]!=v) {
      s->body[ptr++]=s->body[idx];
    } else
      del++;
  }
  s->cnt-=del;
}
#endif