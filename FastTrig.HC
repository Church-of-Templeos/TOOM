F64 cos_table[0x10000];
F64 sin_table[0x10000];
U0 PopulateTables() {
  I64 an;
  for(an=0;an<U16_MAX;an++) {
    cos_table[an]=Cos(an/ToF64(U16_MAX)*2*pi);
    sin_table[an]=Sin(an/ToF64(U16_MAX)*2*pi);
  }
}
PopulateTables;

F64 FCos(F64 a) {
  I64 mul=a/(2*pi)*U16_MAX;
  mul%=0x10000;
  if(mul<0)
    return cos_table[0x10000+mul];
  return cos_table[mul];
}

F64 FSin(F64 a) {
  I64 mul=a/(2*pi)*U16_MAX;
  mul%=0x10000;
  if(mul<0)
    return sin_table[0x10000+mul];
  return sin_table[mul];
}

//https://math.stackexchange.com/questions/1098487/atan2-faster-approximation
F64 FArg(F64 x,F64 y) {
  F64 ax=x,ay=y,a,s,r;
  if(ax<0.) ax=-ax;
  if(ay<0.) ay=-ay;
  if(ax<ay) a=ax/ay;
  else a=ay/ax;
  s=a*a;
  r=((-0.0464964749*s+0.15931422)*s-0.327622764)*s*a+a;
  if(ay>ax) r=1.57079637-r;
  if(x<0) r=pi-r;
  if(y<0) r=-r;
  return r;
} 