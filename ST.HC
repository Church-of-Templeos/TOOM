//#include "Weapons.HC";
extern U0 PlayerAttack(F64 shots_per_min,F64 min_damage,F64 max_damage,F64 range,U64 rocket_type=0);

#define BG 4
#define FG 0
#define SCREENWIDTH 640
#define SCREENHEIGHT 480

/*
**
** 	STATUSBARDATA/DEFINITIONS
**
*/
// For Responder
//#define ST_TOGGLECHAT			KEY_ENTER

// Location of status bar
#define ST_X				0
#define ST_X2				104
#define ST_FX  				143
#define ST_FY  				169

/*
**
** 	GLBLVARS
**
*/


// ST_Start() has just been called
static Bool st_firsttime = FALSE;
// whether left-side main status bar is active
static Bool st_statusbaron;
//used to change display of ammo left
I16 weaponIndex =0;
I32 maxBullets = 200;
I32 maxShells = 50;
I32 maxRockets = 50;
I32 maxCells = 300;

/*
**
** 	CLASSES
**
*/



// Multiple Icon widget
class MultiIcon
{
     // center-justified location of icons
    I64 x;
    I64 y;

    I64 x_off;
    I64 y_off; //Added by nroot

    // last icon number
    I64 oldinum;

    // pointer to current icon
    I64 inum;

    // pointer to boolean stating
    //  whether to update icon
    Bool on;

    // list of icons
    CDC** p;
    
    // user data
    I64 data;
    
};




/*
**
** 	WIDGETS
**
*/



// face status widget
static MultiIcon	toom_faces;  
// weapon anims
static MultiIcon	weapons;

//weapons
static CDC*		PUNCH;
static CDC*		PUNCH1;
static CDC*		PUNCH2;
static CDC*		PUNCH3;
static CDC*		PISTOL;
static CDC*		PISTOLU;
static CDC*		PISTOL1;
static CDC*		PISTOL2;
static CDC*		PISTOL3;
static CDC*		PISTOLF;
static CDC*		SHOTGUN;
static CDC*		SHOTGUN1;
static CDC*		SHOTGUN2;
static CDC*		SHOTGUN3;
static CDC*		SHOTGUNF1;
static CDC*		SHOTGUNF2;
static CDC*		CHAINGUN;
static CDC*		CHAINGUN1;
static CDC*		CHAINGUNF1;
static CDC*		CHAINGUNF2;
static CDC*		MISSILELAUNCHER;
static CDC*		MISSILELAUNCHER1;
static CDC*		MISSILELAUNCHERF1;
static CDC*		MISSILELAUNCHERF2;
static CDC*		MISSILELAUNCHERF3;
static CDC*		MISSILELAUNCHERF4;
static CDC*		CHAINSAW;
static CDC*		CHAINSAW1;
static CDC*		CHAINSAW2;
static CDC*		CHAINSAW3;
static CDC*		PLASMAGUN;
static CDC*		PLASMAGUN1;
static CDC*		PLASMAGUNF1;
static CDC*		PLASMAGUNF2;
static CDC*		BFG;
static CDC*		BFG1;
static CDC*		BFG2;
static CDC*		BFGF1;
static CDC*		BFGF2;

//status bar and faces
static CDC*		ST;
static CDC*		FACE00;
static CDC*		FACE0L;
static CDC*		FACE0R;
static CDC*		FACE10;
static CDC*		FACE1L;
static CDC*		FACE1R;
static CDC*		FACE20;
static CDC*		FACE2L;
static CDC*		FACE2R;
static CDC*		FACE30;
static CDC*		FACE3L;
static CDC*		FACE3R;
static CDC*		FACE40;
static CDC*		FACE4L;
static CDC*		FACE4R;

//numbers
static CDC*		NUM0;
static CDC*		NUM1;
static CDC*		NUM2;
static CDC*		NUM3;
static CDC*		NUM4;
static CDC*		NUM5;
static CDC*		NUM6;
static CDC*		NUM7;
static CDC*		NUM8;
static CDC*		NUM9;
static CDC*		NUMPCT;

static CDC*		NUMS0;
static CDC*		NUMS1;
static CDC*		NUMS2;
static CDC*		NUMS3;
static CDC*		NUMS4;
static CDC*		NUMS5;
static CDC*		NUMS6;
static CDC*		NUMS7;
static CDC*		NUMS8;
static CDC*		NUMS9;

static CDC*		STGNUM[10];
static CDC*		STKEYS[6];
static CDC		*STARMS;
static Bool st_stopped = TRUE;

/*
**
**	FUNCTIONS
**
*/



static I64 st_palette = 0;


I16 GetWeaponIndex()
{
 return weaponIndex;
}

U0 DoomPrint(CDC *dc,I64 x,I64 y,U8 *fmt,...) {
  fmt=StrPrintJoin(NULL,fmt,argc,argv);
  I64 len=StrLen(fmt),idx,c;
  CDC *ch_dc;
  U8 lump_name[16];
  for(idx=0;idx!=len;idx++) {
    c=ToUpper(fmt[idx]);
    if('!'<=c<='_') {
      StrPrint(lump_name,"STCFN%3d",c-'!');
      while(StrOcc(lump_name,' '))
        *StrFirstOcc(lump_name," ")='0';
      ch_dc=FramePtr(lump_name);
      GrBlot(dc,x,y,ch_dc);
      x+=ch_dc->width;
    } else 
     x+=4;
  }
  Free(fmt);
} 

CDC*ReturnSprite(U16 value,Bool large)
{
 if(large)
 {
  switch(value)
  {
   case 0:
     return NUM0;
     break;
   case 1:
     return NUM1;
     break;
   case 2:
     return NUM2;
     break;
   case 3:
     return NUM3;
     break;
   case 4:
     return NUM4;
     break;
   case 5:
     return NUM5;
     break;
   case 6:
     return NUM6;
     break;
   case 7:
     return NUM7;
     break;
   case 8:
     return NUM8;
     break;
   case 9:
     return NUM9;
     break;
   default:
     return NUM0;
     break;

  }
 }
 else
 {
  switch(value)
  {
   case 0:
     return NUMS0;
     break;
   case 1:
     return NUMS1;
     break;
   case 2:
     return NUMS2;
     break;
   case 3:
     return NUMS3;
     break;
   case 4:
     return NUMS4;
     break;
   case 5:
     return NUMS5;
     break;
   case 6:
     return NUMS6;
     break;
   case 7:
     return NUMS7;
     break;
   case 8:
     return NUMS8;
     break;
   case 9:
     return NUMS9;
     break;
   default:
     return NUMS0;
     break;

  }
 
 }
}

U0 DrawNumber(CDoomPlayer *p, U32 x, U32 y,U32 xInc, U16 weapon,Bool small)
{
    //bullets

    U64 ammoNum;
    if(weapon>=8)
    {
      switch(weapon)
      {
       case 8:
        ammoNum=maxBullets;
        break;

       case 9:
        ammoNum=maxShells;
        break;

       case 10:
        ammoNum=maxRockets;
        break;

       case 11:
        ammoNum=maxCells;
        break;
       case 12: //health
        ammoNum=p->health;
        break;
       case 13: //armor
        ammoNum=p->armor;
        break;
      }
    }
    else
    {
      ammoNum = p->arsenal[weapon]->load->ammo;
    }

    U16 hundreds = ammoNum/100;
    U16 remainder = ammoNum%100;
    U16 tens = remainder/10;
    U16 ones = remainder%10;
        
    if(hundreds>0)
    {
     GrBlot(doom_scrn,x,y,ReturnSprite(hundreds,small));
     GrBlot(doom_scrn,x+xInc,y,ReturnSprite(tens,small));
     GrBlot(doom_scrn,x+xInc+xInc,y,ReturnSprite(ones,small));

     if(weapon>=12)
     {
       GrBlot(doom_scrn,x+xInc+xInc+xInc,y,NUMPCT);

     }
    }
    else
    {
     if(tens>0)
     {
      if(!small){
        GrBlot(doom_scrn,x,y,ReturnSprite(tens,small));
        GrBlot(doom_scrn,x+xInc,y,ReturnSprite(ones,small));
      }
      else
      {
        GrBlot(doom_scrn,x+(xInc/2),y,ReturnSprite(tens,small));
        GrBlot(doom_scrn,x+xInc+(xInc/2),y,ReturnSprite(ones,small));
        if(weapon>=12)
        {
         GrBlot(doom_scrn,x+xInc+xInc+(xInc/2),y,NUMPCT);

        }
      }
     }
     else
     {
      if(!small){
        GrBlot(doom_scrn,x,y,ReturnSprite(ones,small));
      }
      else
      {
        GrBlot(doom_scrn,x+xInc,y,ReturnSprite(ones,small));
        if(weapon>=12)
        {
         GrBlot(doom_scrn,x+xInc+xInc,y,NUMPCT);
 
        } 
      }
     }
    }
}


U0 ST_refreshBackground(CDoomPlayer *p)
{
  I64 idx,ix,iy;
  if (st_statusbaron)
    {
//
    //WEAPONS
    //

    if(weapons.data>0)
      {//draw weapons flash
      I16 xmodify=0;
      if(weapons.inum<10&&weapons.inum>3)//pistol
        {
        GrBlot(doom_scrn,weapons.x+18+weapons.x_off,weapons.y-42,
	      weapons.p[weapons.data]);
      }
      if(weapons.inum>=10&&weapons.inum<16)//shotgun
        {
        GrBlot(doom_scrn,weapons.x+38+weapons.x_off,weapons.y-32,
	      weapons.p[weapons.data]);
      }
      if(weapons.inum>=16&&weapons.inum<20&&weapons.on==TRUE)//chaingun
        {
        GrBlot(doom_scrn,weapons.x+32+weapons.x_off,weapons.y-32,
	      weapons.p[weapons.data]);
      }
      if(weapons.inum>=20&&weapons.inum<26)//missile launcher 1
        {
        if(weapons.data>22)
	  xmodify=-16;
        if(weapons.data>23)
	  xmodify=-28;
        if(weapons.data>24)
	  xmodify=-38;  
        GrBlot(doom_scrn,weapons.x+42+xmodify+weapons.x_off,weapons.y-32+xmodify,
	      weapons.p[weapons.data]);
      }
      if(weapons.inum>=34&&weapons.inum<38)//bfg
        {
        if(weapons.data==38)
	  xmodify=-54;

        GrBlot(doom_scrn,weapons.x+72+xmodify+weapons.x_off,weapons.y-16+xmodify,
	      weapons.p[weapons.data]);
      }
    }


    if(weapons.p[weapons.inum])
      GrBlot(doom_scrn,weapons.x+weapons.x_off,weapons.y,
	    weapons.p[weapons.inum]);//weapon


    //STATUSBAR

    GrBlot(doom_scrn,0,SCREENHEIGHT-64,ST); //Read the ST
    GrBlot(doom_scrn,SCREENWIDTH/2-25,SCREENHEIGHT-60,///2-25 -60
	  toom_faces.p[toom_faces.inum]);//faces

    //bullets max
    DrawNumber(p,SCREENWIDTH-44,SCREENHEIGHT-55,10,8,FALSE);
    DrawNumber(p,SCREENWIDTH-44,SCREENHEIGHT-43,10,9,FALSE);        
    DrawNumber(p,SCREENWIDTH-44,SCREENHEIGHT-30,10,10,FALSE);
    DrawNumber(p,SCREENWIDTH-44,SCREENHEIGHT-18,10,11,FALSE);

    //current ammo
    DrawNumber(p,SCREENWIDTH-84,SCREENHEIGHT-55,10,1,FALSE);
    DrawNumber(p,SCREENWIDTH-84,SCREENHEIGHT-43,10,2,FALSE);        
    DrawNumber(p,SCREENWIDTH-84,SCREENHEIGHT-30,10,4,FALSE);
    DrawNumber(p,SCREENWIDTH-84,SCREENHEIGHT-18,10,6,FALSE);

    //current ammo large
    DrawNumber(p,8,SCREENHEIGHT-52,28,weaponIndex,TRUE);
//current health
    DrawNumber(p,SCREENWIDTH-542,SCREENHEIGHT-52,28,12,TRUE);
//current armor
    DrawNumber(p,SCREENWIDTH-282,SCREENHEIGHT-52,28,13,TRUE);    
  }

  GrBlot(doom_scrn,208,SCREENHEIGHT-64,STARMS);

  for(idx=2;idx<=7;idx++) {
    switch(idx) {
      start:
	iy=212*2;
        case 2:
	  ix=111*2+2*12*0;
	  break;
        case :
	  ix=111*2+2*12*1;
	  break;
        case :
	  ix=111*2+2*12*2;
	  break;
      end:
        break;
      start:
	iy=222*2;
        case :
	  ix=111*2+2*12*0;
	  break;
        case :
	  ix=111*2+2*12*1;
	  break;
        case :
	  ix=111*2+2*12*2;
	  break;
      end:;
    }
    if(!p->arsenal[idx]->available) {
      GrBlot(doom_scrn,ix,iy,STGNUM[idx]);
    } else
      GrBlot(doom_scrn,ix,iy,ReturnSprite(idx,FALSE));
    if(l->has_red_key) {
      GrBlot(doom_scrn,2*239,212*2,STKEYS[2]);
    } else if(l->has_blue_key) {
      GrBlot(doom_scrn,2*239,222*2,STKEYS[0]);
    } else if(l->has_yellow_key) {
      GrBlot(doom_scrn,2*239,232*2,STKEYS[1]);
    }

  }
}

U0 ST_refresh(CDoomPlayer *p)
{
  ST_refreshBackground(p);
}

U0 InitWidgets()
{
    toom_faces.p = MAlloc(sizeof(CDC)*40);
    weapons.p = MAlloc(sizeof(CDC)*39);
    toom_faces.inum=0;

    // faces
    //STlib_initMultIcon(&w_faces,
//		       ST_FACESX,
//		       ST_FACESY,
//		       faces,
//		       &st_faceindex,
//		       &st_statusbaron);

}



U0 ST_ReadOnce()
{
  U8 dummy[16];
  I64 idx;
  if(st_firsttime ==FALSE)
    {
//not efficent
    st_firsttime = TRUE;
    InitWidgets();

    //STATUS BARS
    CWadDirectory *wad_dir=wad->body+wad->directory_ptr;  //Wads have a base pointer where the "directories" are stored

    for(idx=0;idx!=10;idx++) {
      StrPrint(dummy,"STGNUM%d",idx);
      STGNUM[idx]=FramePtr(dummy);
    }

    for(idx=0;idx!=6;idx++) {
      StrPrint(dummy,"STKEYS%d",idx);
      STKEYS[idx]=FramePtr(dummy);
    }

    STARMS=FramePtr("STARMS");


    ST = FramePtr("STBAR");
    NUM0=FramePtr("STTNUM0");
    NUM1=FramePtr("STTNUM1");
    NUM2=FramePtr("STTNUM2");
    NUM3=FramePtr("STTNUM3");
    NUM4=FramePtr("STTNUM4");
    NUM5=FramePtr("STTNUM5");
    NUM6=FramePtr("STTNUM6");
    NUM7=FramePtr("STTNUM7");
    NUM8=FramePtr("STTNUM8");
    NUM9=FramePtr("STTNUM9");
    NUMPCT=FramePtr("STTPRCNT");

    NUMS0=FramePtr("STYSNUM0");
    NUMS1=FramePtr("STYSNUM1");
    NUMS2=FramePtr("STYSNUM2");
    NUMS3=FramePtr("STYSNUM3");
    NUMS4=FramePtr("STYSNUM4");
    NUMS5=FramePtr("STYSNUM5");
    NUMS6=FramePtr("STYSNUM6");
    NUMS7=FramePtr("STYSNUM7");
    NUMS8=FramePtr("STYSNUM8");
    NUMS9=FramePtr("STYSNUM9");

    //FACES

    FACE00=FramePtr("STFST01");
    FACE0R=FramePtr("STFST00");
    FACE0L=FramePtr("STFST02");


    //WEAPONS
    //PUNCH
    PUNCH=FramePtr("PUNGA0");
    PUNCH1=FramePtr("PUNGB0");
    PUNCH2=FramePtr("PUNGC0");
    PUNCH3=FramePtr("PUNGD0");

    //PISTOL
    PISTOL=FramePtr("PISGA0");
    PISTOLU=FramePtr("PISGB0");
    PISTOL1=FramePtr("PISGC0");
    PISTOL2=FramePtr("PISGA0");
    PISTOL3=FramePtr("PISGA0");
    PISTOLF=FramePtr("PISFA0");
//SHOTGUN   
    SHOTGUN=FramePtr("SHTGA0");
    SHOTGUN1=FramePtr("SHTGB0");
    SHOTGUN2=FramePtr("SHTGC0");
    SHOTGUN3=FramePtr("SHTGD0");
    SHOTGUNF1=FramePtr("SHTFA0");
    SHOTGUNF2=FramePtr("SHTFB0");
//CHAINGUN
    CHAINGUN=FramePtr("CHGGA0");
    CHAINGUN1=FramePtr("CHGGB0");
    CHAINGUNF1=FramePtr("CHGFA0");
    CHAINGUNF2=FramePtr("CHGFB0");

    //MISSILELAUNCHER
    MISSILELAUNCHER=FramePtr("MISGA0");
    MISSILELAUNCHER1=FramePtr("MISGB0");
    MISSILELAUNCHERF1=FramePtr("MISFA0");
    MISSILELAUNCHERF2=FramePtr("MISFB0");
    MISSILELAUNCHERF3=FramePtr("MISFC0");
    MISSILELAUNCHERF4=FramePtr("MISFD0");

    //CHAINSAW
    CHAINSAW = FramePtr("SAWGA0"); 
    CHAINSAW1 = FramePtr("SAWGB0"); 
    CHAINSAW2 = FramePtr("SAWGC0"); 
    CHAINSAW3 = FramePtr("SAWGAD0"); 

    //PLASMAGUN
    PLASMAGUN = FramePtr("PLSGA0");
    PLASMAGUN1 = FramePtr("PLSGB0");
    PLASMAGUNF1 = FramePtr("PLSFA0");
    PLASMAGUNF2 = FramePtr("PLSFB0");

    //BFG
    BFG=FramePtr("BFGA0");
    BFG1=FramePtr("BFGB0");
    BFG2=FramePtr("BFGC0");
    BFGF1=FramePtr("BFGFA0");
    BFGF2=FramePtr("BFGFB0");

    toom_faces.p[0]=FACE00;
    toom_faces.p[1]=FACE0R;
    toom_faces.p[2]=FACE0L;

    weapons.on=FALSE;
    weapons.inum=0;
    weapons.oldinum=0;
    weapons.x=SCREENWIDTH/3;
    weapons.y=SCREENHEIGHT-106;$IV,1$$IV,0$

    weapons.data=0;

    weapons.p[0]=PUNCH;
    weapons.p[1]=PUNCH1;
    weapons.p[2]=PUNCH2;
    weapons.p[3]=PUNCH3;

    weapons.p[4]=PISTOL;
    weapons.p[5]=PISTOL1;
    weapons.p[6]=PISTOL2;
    weapons.p[7]=PISTOL3;
    weapons.p[8]=PISTOLU;
    weapons.p[9]=PISTOLF;

    weapons.p[10]=SHOTGUN;
    weapons.p[11]=SHOTGUN1;
    weapons.p[12]=SHOTGUN2;
    weapons.p[13]=SHOTGUN3;
    weapons.p[14]=SHOTGUNF1;
    weapons.p[15]=SHOTGUNF2;

    weapons.p[16]=CHAINGUN;
    weapons.p[17]=CHAINGUN1;
    weapons.p[18]=CHAINGUNF1;
    weapons.p[19]=CHAINGUNF2;

    weapons.p[20]=MISSILELAUNCHER;
    weapons.p[21]=MISSILELAUNCHER1;
    weapons.p[22]=MISSILELAUNCHERF1;
    weapons.p[23]=MISSILELAUNCHERF2;
    weapons.p[24]=MISSILELAUNCHERF3;
    weapons.p[25]=MISSILELAUNCHERF4;

    weapons.p[26]=CHAINSAW;
    weapons.p[27]=CHAINSAW1;
    weapons.p[28]=CHAINSAW2;
    weapons.p[29]=CHAINSAW3; 

    weapons.p[30]=PLASMAGUN;
    weapons.p[31]=PLASMAGUN1;
    weapons.p[32]=PLASMAGUNF1;
    weapons.p[33]=PLASMAGUNF2;     

    weapons.p[34]=BFG;
    weapons.p[35]=BFG1;
    weapons.p[36]=BFG2;
    weapons.p[37]=BFGF1;     
    weapons.p[38]=BFGF2;     


  }



}

U0 AnimateFire(CDoomPlayer *p)
{
   if(weapons.on)
   {
    if(p->arsenal[weaponIndex]->load->ammo>0||weaponIndex==0||weaponIndex==5)
    {
     switch(weaponIndex)
     {
     case 0://punch
        switch(weapons.oldinum)
        {
          case -1:
           weapons.oldinum=0;
           weapons.x=SCREENWIDTH/1.5-50;
           weapons.y=SCREENHEIGHT-150;
           weapons.inum=1;
           break;
	  case 0:
           weapons.oldinum=1;
           weapons.x=SCREENWIDTH/1.5-75;
           weapons.inum=2;
           break;
	  case 1:
           weapons.oldinum=2;
	   weapons.x=SCREENWIDTH/1.5-125;
           weapons.inum=3;
           break;
	  case 2:
           weapons.oldinum=3;
           weapons.x=SCREENWIDTH/1.5-75;
           weapons.inum=2;
           break;
	  case 3:
           weapons.oldinum=4;
	   weapons.x=SCREENWIDTH/1.5-50;
           weapons.inum=1;
           break;
	  case 4:
           weapons.x=SCREENWIDTH/3;
           weapons.y=SCREENHEIGHT-106;$IV,1$$IV,0$
           weapons.oldinum=5;
           weapons.inum=0;
           break;
	  case 5:
           weapons.oldinum=0;          
           weapons.inum=0;
           weapons.on=FALSE;
           break;

        }
        break;
      case 1://pistol
	
       switch(weapons.oldinum)
        {
          case -1:
           weapons.oldinum=0;
           weapons.inum=4;
           break;
	  case 0:
           //weapons.x=SCREENWIDTH/3;
           weapons.oldinum=1;
           weapons.inum=5;
           break;
	  case 1:
           weapons.oldinum=2;
           Spawn(&PlaySoundTask,"PISTOL","snd",0,Fs);
           weapons.data=9;
           weapons.inum=7;
           break;
	  case 2:
           weapons.oldinum=3;
           weapons.inum=8;
           break;
	  case 3:
           weapons.oldinum=4;
           weapons.data=0;
           p->arsenal[weaponIndex]->load->ammo--;
           weapons.inum=8;
           break;
	  case 4:
           //weapons.data=0;
           weapons.oldinum=8;
           weapons.inum=8;
           break;
	  case 5://skip
           weapons.oldinum=6;
           weapons.inum=7;
           break;
	  case 6://skip
           weapons.oldinum=7;
           weapons.inum=6;
           break;
          case 7://skip
           weapons.oldinum=8;
           weapons.inum=5;
           break; 
	  case 8:
           //weapons.x=SCREENWIDTH/2.5;
           weapons.oldinum=0;
           weapons.inum=4;
           weapons.on=FALSE;
           break;

        }
        break;
      case 2://shotgun
	Spawn(&PlaySoundTask,"SHOTGN","snd",0,Fs);
       switch(weapons.oldinum)
        {
          case -1:
           //weapons.data=14;
           //weapons.x=SCREENWIDTH/2.16;
           weapons.y=SCREENHEIGHT-164;
           weapons.oldinum=0;
           weapons.inum=10;
           break;
	  case 0:
           weapons.data=15;
           weapons.oldinum=1;
           weapons.inum=10;
           p->arsenal[weaponIndex]->load->ammo--;
           Play("tttA#...");
           break;
	  case 1:
           weapons.data=14;
           weapons.oldinum=2;
           weapons.inum=10;
           //Play("1A");
           break;
	  case 2:            
           weapons.data=0;
           weapons.oldinum=3;
           weapons.inum=10;
           break;
	  case 3:
           weapons.oldinum=4;
           weapons.inum=11;
           weapons.x=SCREENWIDTH/4.5;
           weapons.y=SCREENHEIGHT-306;
	   Sleep(40);
           break;
	  case 4:
           weapons.oldinum=5;
           weapons.inum=12;
	   Sleep(40);
           break;
 	  case 5:
           weapons.oldinum=6; 
           weapons.inum=13;
           Sleep(40);
           break;
	  case 6:
           weapons.oldinum=7;
           weapons.inum=12;
	   Sleep(40);
           break;
	  case 7:
           weapons.x=SCREENWIDTH/2.5;
           weapons.y=SCREENHEIGHT-184;
           weapons.oldinum=8;
	   weapons.inum=11;
           Sleep(40);
           break;	 
	  case 8:
           weapons.oldinum=0;
           weapons.inum=10;
           weapons.on=FALSE;
           break;

        }
        break;
      case 3://chaingun
	Spawn(&PlaySoundTask,"PISTOL","snd",0,Fs);
       switch(weapons.oldinum)
        {
          case -1:
            //weapons.x=
            weapons.oldinum=0;
            weapons.data=19;
            weapons.inum=17;
            p->arsenal[weaponIndex]->load->ammo--;
	    Sleep(5);
            break;
          case 0:
            weapons.oldinum=0;
            weapons.data=18;
            p->arsenal[weaponIndex]->load->ammo--; 
            weapons.inum=16;
            Sleep(5);
            weapons.on=FALSE;
            break;
        }
        break;
      case 4://missile launcher
	Spawn(&PlaySoundTask,"RLAUNC","snd",0,Fs);      
       switch(weapons.oldinum)
        {
          case -1:
            weapons.oldinum=0;
            weapons.inum=21;
            weapons.data=22;
            weapons.y=weapons.y+25;
            p->arsenal[weaponIndex]->load->ammo--;
            Sleep(5);
            break;
          case 0:
            weapons.oldinum=1;
            weapons.data=23;
            Sleep(5);
            break;
          case 1:
            weapons.oldinum=2;
            weapons.data=24;
            weapons.y=weapons.y-15;
            Sleep(5);
            break;
          case 2:
            weapons.oldinum=3;
            weapons.data=25;
            weapons.y=weapons.y-5;
            Sleep(5);
            break;
          case 3:
            weapons.oldinum=0;
            weapons.data=0;
            weapons.y=weapons.y-5;
            weapons.inum=20;
            Sleep(5);
            weapons.on=FALSE;
            break;
             
        }
        break;
      case 5://chainsaw
	Spawn(&PlaySoundTask,"SAWFUL","snd",0,Fs);      
       switch(weapons.oldinum)
        {
          case -1:
            weapons.oldinum=0;
            weapons.inum=27;
            break;
          case 0:
            weapons.oldinum=1;
            weapons.inum=28;
            weapons.y=weapons.y-86;
            break;
          case 1:
            weapons.oldinum=2;
            weapons.inum=29;
            break;
          case 2:
            weapons.oldinum=3;
            weapons.inum=28;
            break;
          case 3:
            weapons.oldinum=0;
            weapons.y=weapons.y+86;
            weapons.inum=27;
            weapons.on=FALSE;
            break;
        }
        break;
      case 6://plasma gun
       Spawn(&PlaySoundTask,"PLASMA","snd",0,Fs);      
       switch(weapons.oldinum)
        {
          case -1:
            weapons.oldinum=0;
            weapons.inum=32;
            //weapons.data=32;
            Sleep(20);
            break;
          case 0:
            weapons.oldinum=1;
            weapons.inum=33;
            p->arsenal[weaponIndex]->load->ammo--;
            Sleep(20);
            //weapons.data=33;
            break;
          case 1:
            weapons.oldinum=2;
            weapons.x=weapons.x-86;
            weapons.y=weapons.y-92;
            weapons.inum=31;
            Sleep(240);
            break;
          case 2:
            weapons.oldinum=0;
            weapons.inum=30;
            weapons.data=0;
            weapons.x=weapons.x+86;
            weapons.y=weapons.y+92;
            weapons.on=FALSE;
            break;
        }
        break;
      case 7://BFG
       Spawn(&PlaySoundTask,"BFG","snd",0,Fs);      
       switch(weapons.oldinum)
        {
          case -1:
            weapons.oldinum=0;
            weapons.inum=35;
            //weapons.data=32;
            Sleep(20);
            break;
          case 0:
            weapons.oldinum=1;
            weapons.inum=36;
            weapons.data=37;
            Sleep(20);
            //weapons.data=33;
            break;
          case 1:
            weapons.oldinum=2;
            weapons.data=38;
            Sleep(60);
            //weapons.data=33;
            p->arsenal[weaponIndex]->load->ammo--;
            break;
          case 2:
            weapons.oldinum=0;
            weapons.inum=35;
            weapons.data=0;
            weapons.on=FALSE;
            break;
        }
        break;
     }
    }
    else
    {
     Sleep(5);
     weapons.oldinum=0;
     //weapons.inum=0;
     weapons.on=FALSE;
     weapons.data=0;      
    }

   }
}

U0 SwapWeapon(CDoomPlayer *p,I64 weapon)
{
  if(!weapons.on)
  {
  if(!p->arsenal[weapon]->available)
    return;
  weaponIndex = weapon;

  switch(weapon)
  {
   case 0:
    weapons.x=SCREENWIDTH/3;
    weapons.x_off = 0;
    weapons.y=SCREENHEIGHT-106;
    weapons.inum=0;//hands
    weapons.data=0;
    weapons.on=FALSE;
    break;
   case 1:
    //weapons.on=TRUE;
    weapons.x=SCREENWIDTH/2.5;
    weapons.y=SCREENHEIGHT-186;$IV,1$$IV,0$
    weapons.data=0;
    weapons.inum=8;//pistol 
    weapons.inum=5;
    weapons.inum=4;
    weapons.on=FALSE;
    break;
   case 2:
    //weapons.on=TRUE;
    weapons.x=SCREENWIDTH/2.5;
    weapons.y=SCREENHEIGHT-184;$IV,1$$IV,0$
    weapons.data=0;
    weapons.inum=12;//shotgun
    weapons.inum=11;//shotgun
    weapons.inum=10;//shotgun
    weapons.on=FALSE;
    
    break;
   case 3:
    //weapons.on=TRUE;
    weapons.x=SCREENWIDTH/3;
    weapons.y=SCREENHEIGHT-184;$IV,1$$IV,0$//chaingun
    weapons.data=0;
    weapons.inum=17;
    weapons.inum=16;
    weapons.on=FALSE;
    
    break;
   case 4:
    //weapons.on=TRUE;
    weapons.x=SCREENWIDTH/2.75;
    weapons.y=SCREENHEIGHT-184;$IV,1$$IV,0$
    weapons.data=0;
    weapons.inum=21;//missile launcher
    weapons.inum=20;
    weapons.on=FALSE;
    
    break;
   case 5:
    //weapons.on=TRUE;
    weapons.x=SCREENWIDTH/3.5;
    weapons.y=SCREENHEIGHT-146;$IV,1$$IV,0$
    weapons.data=0;
    //weapons.inum=29;//chainsaw
    //weapons.inum=28;
    //weapons.inum=27;
    weapons.inum=26;
    weapons.on=FALSE;
    
    break;
   case 6:
    //weapons.on=TRUE;
    weapons.x=SCREENWIDTH/2.75;
    weapons.y=SCREENHEIGHT-184;$IV,1$$IV,0$
    weapons.data=0;
    weapons.inum=31;//plasma gun
    weapons.inum=30;
    weapons.on=FALSE;
    
    break;
   case 7:
    //weapons.on=TRUE;
    weapons.x=SCREENWIDTH/4;
    weapons.y=SCREENHEIGHT-184;$IV,1$$IV,0$
    weapons.data=0;
    weapons.inum=36;//BFG
    weapons.inum=35;
    weapons.inum=34;
    weapons.on=FALSE;
    
    break;
   
   }
  }
}

U0 ST_Fire(CDoomPlayer *p)
{
  if(weapons.on==FALSE)
    {
    weapons.on=TRUE;
    weapons.oldinum=-1;

    switch(weaponIndex) {
      case 0: //First
//TODO test for beserk
        PlayerAttack(123.5,2,20,32);
        break;
      start:
        case 1: //Pistol
	  if(p->arsenal[weaponIndex]->load->ammo>0)
	    PlayerAttack(150.,5,15,200*64.);
	  break;
        case 2: //Shotgun
	  if(p->arsenal[weaponIndex]->load->ammo>0)
	    PlayerAttack(56.8,5,15,200*64.);
	  break;
        case 3: //Chainhun
	  if(p->arsenal[weaponIndex]->load->ammo>0)
	    PlayerAttack(525,5,15,200*64.);
	  break;
        case 4: //Rocket
	  if(p->arsenal[weaponIndex]->load->ammo>0)
	    PlayerAttack(105,20,160,200*64.,'Rocket');
	  break;
        case 5: //Chainsaw
	  PlayerAttack(525,2,20,32);
	  break;
        case 6: //Plsmaa
	  if(p->arsenal[weaponIndex]->load->ammo>0)
	    PlayerAttack(700,5,40,200*64.,'Plasma');
	  break;
        case 7: //Big poopin gun
//TODO tracer
	  if(p->arsenal[weaponIndex]->load->ammo>0)
	    PlayerAttack(52.5,100,800,200*64.,'BFG');
	  break;
      end:
        p->made_a_sound=TRUE;
    }
  }
}

U0 ST_Key(U16 val)
{
   switch(val)
   {
     case 0: //release
       toom_faces.inum=0;
       break;
     case 1: //right
       toom_faces.inum=1;
       break;
     case 2: //left
       toom_faces.inum=2;
       break;

   }

}

U0 ST_Start(CDoomPlayer *p)
{
    st_statusbaron=TRUE;
    ST_ReadOnce();
    ST_refresh(p);
    //ST_createWidgets();
    //ST_refresh();

}

U0 ST_Exit()
{
  Free(toom_faces.p);
  Free(weapons.p);
}

//ST_Start;
