U8 *iwad,*pwad;

I64 WadDefineLst(U8 *to=NULL,U8 t='I') {
  I64 len=0;
  CDirEntry *root=FilesFind("*.WAD*;*.wad*",FUF_JUST_FILES),*cur;
  for(cur=root;cur;cur=cur->next) {
    if(t=='I') {
      if(IsIWad(cur->full_name)) { 
pass:;
        if(to) {
	  StrCpy(to+len,cur->name);
        }
        len+=StrLen(cur->name)+1;
      }
    } else if(t=='P'&&IsPWad(cur->full_name)) {
      goto pass;
    }
  }
  if(to)
    to[len]=0;
  len++;
  DirEntryDel(root);
  return len;
}

class CDoomWads {
  I64 iwad format "Main Wad:$$LS,D=\"DOOM_IWADS\"$$\n";
  I64 pwad format "Mod Wad:$$LS,D=\"DOOM_PWADS\"$$\n";
};

U0 PickWads() {
  U8 *iwad_lst,*wad;
  U8 *pwad_lst,*pwad;
  I64 len;
  CDoomWads wads;
  wads.iwad=0;
  wads.pwad=0;
  len=WadDefineLst(NULL,'I');
  iwad_lst=CAlloc(len);
  WadDefineLst(iwad_lst,'I');

  len=WadDefineLst(NULL,'P')+StrLen("None")+1;
  pwad_lst=CAlloc(len);
  StrCpy(pwad_lst,"None");
  WadDefineLst(pwad_lst+StrLen(pwad_lst)+1,'P');

  DefineLstLoad("DOOM_IWADS",iwad_lst);
  DefineLstLoad("DOOM_PWADS",pwad_lst);

  DocForm(&wads,,,"$$PURPLE$$$$TX+CX,\"Pick your main WAD and a Mod\"$$$$FD$$\n  You can choose NONE for a mod if you want a classic expirnce.\n");


  wad=DefineSub(wads.iwad,"DOOM_IWADS");
  pwad=DefineSub(wads.pwad,"DOOM_PWADS");
  if(!wad) {
    PopUpOk("Can't find a main WAD aborting.\n");
    Exit;
  } else {
    if(StrOcc(wad,'2'))
      FramePtrAdd("DOOM2",1);
    LoadWad(iwad=wad);
  }
  if(pwad&&FileFind(pwad))
    LoadWad(pwad);

  Free(iwad_lst);
  Free(pwad_lst);
}

if(iwad=FramePtr("USE_IWAD")) {
  if(!FileFind(iwad)) {
    PopUpOk(MStrPrint("Can't find IWAD \"%Q\"\n",iwad));
    Exit;
  }
  LoadWad(iwad);
}  else
  PickWads;
if(pwad=FramePtr("USE_PWAD")) {
  if(!FileFind(pwad)) {
    PopUpOk(MStrPrint("Can't find PWAD \"%Q\"\n",pwad));
    Exit;
  }
}
