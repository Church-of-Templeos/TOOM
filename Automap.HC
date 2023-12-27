#ifndef AUTOMAP_H 
#define AUTOMAP_H "Poopsauce"
class CAutomapState {
  F64 x,y;
  F64 zoom,angle;
  Bool follow,active,all;
} am_state;
MemSet(&am_state,0,sizeof CAutomapState);
am_state.follow=TRUE;
am_state.zoom=1;
U0 AutomapInteract() {
  static F64 button_delay=0;
  if(Bt(kbd.down_bitmap,Char2ScanCode('\t')))
    if(button_delay+.1<tS)
      am_state.active^=TRUE,button_delay=tS;
  if(!am_state.active) return;

  if(Bt(kbd.down_bitmap,Char2ScanCode('f')))
    if(button_delay+.1<tS)
      am_state.follow^=TRUE,button_delay=tS;
  if(am_state.follow) {
    am_state.x=p->x;
    am_state.y=p->y;
    am_state.angle=p->angle;
  } else {
    if(Bt(kbd.down_bitmap,Char2ScanCode('w')))
      am_state.y-=am_state.zoom;
    else if(Bt(kbd.down_bitmap,Char2ScanCode('s')))
      am_state.y+=am_state.zoom;
    else if(Bt(kbd.down_bitmap,Char2ScanCode('a')))
      am_state.x-=am_state.zoom;
    else if(Bt(kbd.down_bitmap,Char2ScanCode('d')))
      am_state.x+=am_state.zoom;
  }
  if(Bt(kbd.down_bitmap,Char2ScanCode('='))) {
    am_state.zoom+=.1;
  } else if(Bt(kbd.down_bitmap,Char2ScanCode('-'))) {
    am_state.zoom-=.1;
  }
  am_state.zoom=Clamp(am_state.zoom,1/16.,1.);
}
U0 DrawAutomap(CDC *dc,CDoomLevel *l) {
  I64 mat;
  Bool all=l->has_map;
  F64 x=am_state.x;
  F64 y=am_state.y;
  F64 zoom=am_state.zoom;
  F64 rot=am_state.angle;
  dc->flags|=DCF_TRANSFORMATION;
  DCFill(dc,BLACK);
  Mat4x4IdentEqu(dc->r);
  Mat4x4TranslationEqu(dc->r,-x,-y,0);
  Mat4x4RotZ(dc->r,-rot+pi/2);
  Mat4x4RotX(dc->r,pi); //Our view is flipped in TOOM
  Mat4x4Scale(dc->r,am_state.zoom);
  Mat4x4TranslationAdd(dc->r,GR_WIDTH/2,GR_HEIGHT/2,0);
  CDoomLinedef *ld,*head;
  CDoomActionSector *special;
  head=&l->linedefs;
  for(ld=head->next;ld!=head;ld=ld->next) {
    if(!ld->seen&&!all)
      goto skip;
//RED is solid line
      //YELLOW is door/ceil
      //BROWN is floor 
      //GRAY not yet seen
    if(!ld->seen&&all) {
      dc->color=LTGRAY;
    } else if(special=ld->special_type) {
      if(special->door.type=='Ceil') {
        dc->color=YELLOW;
      } else if(special->door.type=='Door') {
        dc->color=YELLOW;
      } else if(special->door.type=='Lift') {
        dc->color=BROWN;
      } else if(special->door.type=='Stairs') {
        dc->color=BROWN;
      } else if(special->door.type=='Donut') {
        dc->color=BROWN;
      }
    } else {
      dc->color=RED;
    }
    dc->thick=3;
    GrLine3(dc,ld->start->x,ld->start->y,0,ld->end->x,ld->end->y,0);
skip:;
  }
  dc->color=WHITE;
  GrArrow3(dc,
        p->x,
        p->y,
        0,
        p->x+32*Cos(p->angle),
        p->y+32*Sin(p->angle),
        0);
}
#endif;