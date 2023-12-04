#ifndef MENU
#define MENI "poop"
class CMenuItem {
  U64 value;
  CDC *gr;
  I16 state; //-1 for end
  I16 x,y;
  U8 name[29];
  U8 hot_key;
};
//Free this
CMenuItem *CreateMenu(...) {
  CMenuItem *ret=CAlloc(sizeof(CMenuItem)*(1+argc/3));
  I64 idx;
  for(idx=0;idx<argc/3;idx++) {
    StrCpy(ret[idx].name,argv[idx*3]);
    ret[idx].hot_key=argv[idx*3+2];
    ret[idx].value=argv[idx*3+1];
  }
  ret[idx].state=-1;
  return ret;
}
U64 Menu(CMenuItem *items,I64 offx,I64 offy) {
  I64 code=INVALID_PTR;
  I64 cur_active=0;
  CDC *skull;
  I64 a,b;
  I64 msx=ms.pos.x;
  I64 msy=ms.pos.y;
  I64 x,y;
  I64 h=0,basey;
  I64 cnt=0,idx;
  h=offy*2;
  for(cur_active=0;items[cur_active].state!=-1;cur_active++) {
    skull=FramePtr(items[cur_active].name);
    items[cur_active].gr=skull;
    items[cur_active].x=offx*2;
    items[cur_active].y=h;
    h+=20+skull->height;
    cnt++;
  }
  cur_active=0;
  FlushMsgs;
  while(code==INVALID_PTR) {
    if(Blink)
      skull=FramePtr("M_SKULL1");
    else
      skull=FramePtr("M_SKULL2");
retry:
    switch(ScanMsg(&a,&b)) {
      case 0:
	break;
      start:
        msx=ms.pos.x;
        msy=ms.pos.y;
        for(idx=0;idx!=cnt;idx++) {
	  y=items[idx].y;
	  if(y<=msy<=y+items[idx].gr->height) {
	    cur_active=idx;
	    break;
	  }
        }
        case MSG_MS_MOVE:
	  break;
        case MSG_MS_L_DOWN:
	  code=items[cur_active].value;
	  break;
      end:
        goto retry;  //try all events for frame
      case MSG_KEY_DOWN:
        if(b&0xff==SC_CURSOR_UP&&cur_active>0) {
	  cur_active--;
        } else if(b&0xff==SC_CURSOR_DOWN&&cur_active+1<cnt) {
	  cur_active++;
        } else if(a=='\n') {
	  code=items[cur_active].value;
        } else if(a==CH_ESC) {
	  code=0;
	} else {
          for(idx=0;idx!=cnt;idx++) {
	    if(items[idx].hot_key==a)
	      code=items[cur_active].value;
	  }
	}
      default:
        goto retry; //try all events for frame
    }
    DCFill;
    for(idx=0;idx!=cnt;idx++) {
      GrBlot(gr.dc,items[idx].x,items[idx].y,items[idx].gr);
      if(cur_active==idx) {
        x=items[idx].x-skull->width-10;
        y=items[idx].y+items[idx].gr->height/2-skull->height/2;
        GrBlot(gr.dc,x,y,skull);
      }
    }
    Refresh;
  }  
  DCFill;
  Spawn(&PlaySoundTask,"SWTCHN","snd",0,Fs);
  return code;
}
U64 EpisodeMenu() {
  CMenuItem *items=CreateMenu(
    "M_EPI1",'1','1',
    "M_EPI2",'2','2',
    "M_EPI3",'3','3',
    "M_EPI4",'4','4',
  );
  U64 r=Menu(items,48,63);
  Free(items);
  return r;
}
U64 NewGameMenu() {
  CMenuItem *items=CreateMenu(
    "M_JKILL",'1','i',
    "M_ROUGH",'2','h',
    "M_HURT",'3','h',
    "M_ULTRA",'4','u',
    "M_NMARE",'5','n',
  );
  U64 r=Menu(items,48,63);
  Free(items);
  return r;
}


U64 MainMenu() {
againm:;
  CMenuItem *items=CreateMenu(
    "M_NGAME",'NGAME','n',
    "M_LOADG",'LOADG','l',
    "M_SAVEG",'SAVEG','s',
    "M_RDTHIS",'RDTHIS','r',
    "M_QUITG",'QUITG','q'
  );
  U8 level[STR_LEN];
  CDoomLevel *doom_level;
  U64 r=Menu(items,97,64),s,ep;
  Free(items);
  if(r=='NGAME') {
episode:
    ep=EpisodeMenu;
    switch(ep) {
      case '1':
      case '2':
      case '3':
      case '4':
	StrPrint(level,"E%cM1",ep);
	switch(s=NewGameMenu) {
	  case '1':
	  case '2':
	  case '3':
	  case '4':
	  case '5':
	   if(l)
             FreeLevel(l);
           doom_level=PlayLevel(level,s-'1'+1);
	  break;
	  default:
	    goto episode;
	}
	break;
    }
  } else if(r=='LOADG') {
//TODO
  } else if(r=='SAVEG') {
//TODO
  } else if(r=='RDTHIS') {
  } else if(r=='QUITG') {
    Exit;
  }
  goto againm;
}