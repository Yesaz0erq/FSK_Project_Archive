// Native-resolution artwork with connected pixel clusters; no screen downsampling.
const fs=require('fs');fs.mkdirSync('assets/terrain',{recursive:true});
const specs={sheet_sand:['#b5a071','#756044',['#c4ae7b','#a78f60','#d0bb89']],sheet_grass:['#648455','#65523e',['#6e8c5b','#557448','#819967']],sheet_burnt:['#48434c','#40353b',['#554a50','#37333e','#68544f']],sheet_river:['#39748c','#4b5b60',['#438198','#30657c','#629cad']],sheet_riverbed:['#8e8066','#695641',['#a09174','#786b55','#b2a58b']],sheet_oasis:['#5b8463','#685b42',['#6c9771','#4d765b','#8fa67c']]};
for(const[id,[base,soil,palette]]of Object.entries(specs)){
 let state=42+Object.keys(specs).indexOf(id)*117;
 const rand=n=>{state=(Math.imul(state,1664525)+1013904223)>>>0;return state%n;};
 const rect=(x,y,w,h,c)=>`<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="${c}"/>`;
 const path=(d,c,w=4)=>`<path d="${d}" fill="none" stroke="${c}" stroke-width="${w}" stroke-linejoin="miter"/>`;
 let top=rect(0,0,256,256,base);
 for(let i=0;i<45;i++)top+=rect(4+rand(60)*4,4+rand(60)*4,4+rand(4)*4,4+rand(3)*4,palette[rand(3)]);
 if(id==='sheet_sand')for(let row=0;row<7;row++){const y=20+row*34,q=rand(4)*4;top+=path(`M8 ${y+q} H48 V${y-4+q} H108 V${y-8+q} H160 V${y-12+q} H244`,palette[0],4)+path(`M16 ${y+8+q} H56 V${y+4+q} H112 V${y+q} H168 V${y-4+q} H248`,palette[1],3);}
 if(id==='sheet_grass'||id==='sheet_oasis'){
  for(let i=0;i<10;i++){const x=12+rand(54)*4,y=12+rand(54)*4;top+=rect(x,y,16,8,'#566743')+rect(x+4,y-4,16,8,'#5e7349');}
  for(let i=0;i<20;i++){const x=8+rand(58)*4,y=8+rand(58)*4;top+=rect(x,y,4,12,palette[1])+rect(x-4,y+4,12,4,palette[2]);if(i%5===0)top+=rect(x,y-4,4,4,'#c7c390');}
 }
 if(id==='sheet_burnt'){
  for(let i=0;i<10;i++){const x=12+rand(54)*4,y=12+rand(54)*4;top+=path(`M${x} ${y} h16 v8 h12 v16 h8`,'#2d2a34',4);}
  for(let i=0;i<8;i++)top+=rect(12+rand(56)*4,12+rand(56)*4,12,4,'#8c5d50');
 }
 if(id==='sheet_riverbed'){
  for(let i=0;i<14;i++){const x=8+rand(55)*4,y=8+rand(55)*4;top+=rect(x,y+4,20,12,'#665f51')+rect(x+4,y,12,12,palette[2])+rect(x+4,y,8,4,'#c0b49a');}
  for(let i=0;i<5;i++){const y=24+i*44;top+=path(`M4 ${y} h44 v8 h60 v-4 h60 v8 h76`,palette[1],4);}
 }
 if(id==='sheet_river')for(let i=0;i<24;i++){const x=8+rand(54)*4,y=8+rand(58)*4;top+=rect(x,y,16+rand(6)*4,4,i%3===0?palette[2]:palette[0]);if(i%3===0)top+=rect(x+8,y+4,20,4,palette[0]);}
 if(id==='sheet_oasis'){top+='<path d="M72 56H176V68H192V88H204V164H192V184H168V196H88V184H64V160H52V92H64V72H72Z" fill="#9f9d72"/><path d="M80 68H168V80H184V96H192V156H180V172H160V184H96V172H76V152H64V100H76V80H80Z" fill="#376d83"/>';top+=rect(92,92,48,4,'#6caaa9')+rect(100,96,56,4,'#569391')+rect(112,152,48,4,'#6caaa9');}
 top+=path('M1 255V1H255','#3c4b47',2)+path('M255 1V255H1','#344139',2);
 let side=rect(0,0,256,256,soil);
 for(let layer=0;layer<6;layer++){const y=28+layer*36;side+=rect(0,y,256,8,layer%2?'#58493b':'#897252');for(let i=0;i<12;i++)side+=rect(rand(62)*4,y+8+rand(4)*4,12+rand(5)*4,4,layer%2?'#75624c':'#64533f');}
 side+=rect(0,0,256,24,base);for(let x=0;x<256;x+=16)side+=rect(x,20,16,4+rand(3)*4,base);
 side+=rect(0,0,256,4,palette[0])+rect(0,248,256,8,'#302f34');
 for(const[part,body]of [['top',top],['side',side]])fs.writeFileSync(`assets/terrain/${id}_${part}.svg`,`<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256" shape-rendering="crispEdges">${body}</svg>`);
}
