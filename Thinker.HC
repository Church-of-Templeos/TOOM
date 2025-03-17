#ifndef THINKER_H
#define THINKER_H "BigBrain"
class CDoomThinkerBase:CQue {
  U8 cls_name[64];
  U8 (*fun_ptr)(CDoomLevel *,CDoomThinkerBase *);
};
class CDoomThinker:CDoomThinkerBase {
  I64 user_data1;
};

Bool GCUnusedThings(CDoomLevel *l) {
  CDoomThing *thing=l->obselete_things.next,*next;
  CDoomThinker *thinker=l->thinkers.next;
  U8 buf[STR_LEN];
  CDoomThing **tt;
  I64 idx,cnt;
  while(thing!=&l->obselete_things) {
    StrPrint(buf,"T.%X",thing);
    FramePtrAdd(buf,FALSE);
    thing=thing->next;
  }
//TODOput in hash table
  while(thinker!=&l->thinkers) {
    cnt=MSize(thinker)/8;
    tt=thinker;
    while(--cnt>=0) {
      StrPrint(buf,"T.%X",tt[cnt]);
      FramePtrSet(buf,1); //Wont make a new entry
    }
    thinker=thinker->next;
  }
  thing=l->obselete_things.next;
  while(thing!=&l->obselete_things) {
    next=thing->next;
    StrPrint(buf,"T.%X",thing);
    if(!FramePtr(buf)) {
      QueRem(thing);
      Free(thing);
    }
    FramePtrDel(buf);
    thing=next;
  }
}
U0 UpdateThinkers(CDoomLevel *l) {
//There are lots of monsters,be sure to only update about 10 times a second(game runs at 30 fps)
  static F64 next_monster=tS;
  Bool do_monster=FALSE;
  if(tS>next_monster) {
    do_monster=TRUE;
    next_monster=tS+1/10.;
  }
  CDoomThinker *head=&l->thinkers,*cur,*next;
  for(cur=head->next;head!=cur;cur=next) {
    next=cur->next; //thinker may be deleted
    if(!do_monster&&!StrCmp(cur->cls_name,"CMonsterThinker"))
     goto skip;
    (*cur->fun_ptr)(l,cur);
skip:
  }

  if(do_monster)
    GCUnusedThings(l);
}
CDoomThinker *AddThinker(CDoomLevel *l,U8 (*fun_ptr)(CDoomLevel *,CDoomThinker *),U8 *cls_name) {
  CHashClass *cls=HashFind(cls_name,Fs->hash_table,HTT_CLASS);
  if(!cls) throw('Class');
  CDoomThinker *t=CAlloc(cls->size,doom_task);
  StrCpy(t->cls_name,cls_name);
  QueIns(t,l->thinkers.next);
  t->fun_ptr=fun_ptr;
  return t;
}
U0 DestroyThinkers(CDoomLevel *l) {
  QueDel(&l->thinkers);
  QueInit(&l->thinkers);
}

#endif