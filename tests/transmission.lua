-- Native-shaped contract harness, not an emulation of FS25 tire/soil physics.
local count=0
local function check(v,msg) count=count+1;assert(v,msg) end
Class=function(t) return {__index=t} end
Event={new=function(mt) return setmetatable({},mt) end}
InitEventClass=function() end
Logging={info=function() end,warning=function() end}
Motorized={loadMotor=function() end,loadDifferentials=function() end,onRegisterActionEvents=function() end}
WheelPhysics={loadFromXML=function() return true end};Wheel={update=function() end}
g_currentModDirectory='/mods/FS25_Ursus_1654_1954_Pack/';g_time=10000
VehicleMotor={SHIFT_MODE_AUTOMATIC=1}
function VehicleMotor:getBestStartGear() return 1,1,'native' end
function VehicleMotor:getUseAutomaticGroupShifting() return true end
function VehicleMotor:findGearChangeTargetGearPrediction(cur) return self.nativeTarget or cur end
function VehicleMotor:applyTargetGear()
 self.applied=(self.applied or 0)+1;self.gear=self.targetGear
 self.appliedGroup=self.activeGearGroupIndex
end
function VehicleMotor:setGearGroup(h)
 if self.activeGearGroupIndex~=h then
  self.groupEvents=(self.groupEvents or 0)+1;self.activeGearGroupIndex=h
  self:applyTargetGear() -- the real PS setter applies immediately!
 end
end
function VehicleMotor:updateGear(acc,brake,dt)
 if self.throw then error('original exception') end
 if self.bypass then return .25,.75,nil,'tail',nil end
 if self.gearChangeTimer>=0 then
  self.gearChangeTimer=self.gearChangeTimer-dt
  if self.gearChangeTimer<0 then self:applyTargetGear() end
  return 0,brake
 end
 local target
 if self.start then target=self:getBestStartGear(self.currentGears);self.start=false
 else target=self:findGearChangeTargetGearPrediction(self.gear,self.currentGears,self.currentDirection,0,acc,dt) end
 if self.veto or (self.allowGearChangeTimer>0 and target<self.gear and self.allowGearChangeDirection==1) then target=self.gear end
 if target~=self.gear then
  self.previousGear=self.gear;self.targetGear=target;self.gear=0;self.gearChangeTimer=350
  return 0,brake
 end
 return acc,brake
end
local originalPrediction=VehicleMotor.findGearChangeTargetGearPrediction
dofile('UrsusTransmissionFix.lua')
local function motor(g,h)
 local v={configFileName=g_currentModDirectory..'Ursus1934.xml',isServer=true,speed=20,mass=8.8,limit=math.huge}
 function v:getLastSpeed() return self.speed end
 function v:getTotalMass() return self.mass end
 function v:getSpeedLimit(tools) return tools and self.limit or math.huge,false end
 v.spec_AdvancedDamageSystem={dynamicMotorLoad=.3,activeEffects={}}
 v.spec_wheels={wheels={ {},{}, {physics={netInfo={slip=0}}},{physics={netInfo={slip=0}}} }}
 local m=setmetatable({vehicle=v,gear=g or 7,targetGear=g or 7,activeGearGroupIndex=h or 2,
  currentDirection=1,gearShiftMode=1,gearGroups={{ratio=1.25},{ratio=1}},gearChangeTimer=-1,
  groupChangeTimer=0,directionChangeTimer=0,allowGearChangeTimer=0,allowGearChangeDirection=1,
  rpm=2200,maxRpm=2200,nativeLoad=.3,currentGears={}}, {__index=VehicleMotor})
 for _,speed in ipairs({3.4,5.4,7.8,10.4,14.2,19,25.9,40}) do
  table.insert(m.currentGears,{ratio=2200*math.pi/(30*speed/3.6)})
 end
 function m:getLastModulatedMotorRpm() return self.rpm end
 function m:getSmoothLoadPercentage() return self.nativeLoad end
 function m:getTorqueCurveValue(rpm) return rpm>0 and 1 or 0 end
 return m
end
local function tick(m,dt,acc,brake)
 g_time=g_time+(dt or 50);return m:updateGear(acc or 1,brake or 0,dt or 50)
end
local function run(m,n) for i=1,n do tick(m) end end
local function up(m)
 for i=1,100 do tick(m);if m.gear==0 then return end end
 error('No shift: '..(m.ursusAuto and m.ursusAuto.reason or '?'))
end
-- All return values, non-target/manual/no-PS/client isolation.
for _,mode in ipairs({'other','manual','noPS','client','target'}) do
 local m=motor();m.bypass=true
 if mode=='other' then m.vehicle.configFileName='/other/Ursus1934.xml' end
 if mode=='manual' then m.gearShiftMode=2 end
 if mode=='noPS' then m.gearGroups=nil end
 if mode=='client' then m.vehicle.isServer=false end
 local r=table.pack(tick(m));check(r.n==5 and r[1]==.25 and r[2]==.75 and r[3]==nil and r[4]=='tail' and r[5]==nil,'returns '..mode)
 if mode~='target' then check(m.ursusAuto==nil,'isolation '..mode) end
end
local m=motor();m.throw=true;check(not pcall(tick,m),'native exceptions propagate')
m=motor(8,1);m.vehicle.speed=32;run(m,30);check(m.gear==8 and m.activeGearGroupIndex==2,'8L to 8H without 9th gear')
-- Road starts in H, working start in L. No changes on read-only start queries.
m=motor(1,1);m.vehicle.speed=0
local a,b=m:getBestStartGear(m.currentGears);check(a==1 and b==1 and m.ursusAuto.pending==nil,'start query pure')
m.start=true;tick(m);check(m.gear==0 and m.targetGear==2 and m.activeGearGroupIndex==1,'road start planned')
run(m,8);check(m.gear==2 and m.activeGearGroupIndex==2,'road start 2H')
m=motor(5,2);m.vehicle.speed=0;m.vehicle.limit=12.2;m.start=true;tick(m);run(m,8)
check(m.gear==1 and m.activeGearGroupIndex==1,'loaded start 1L')
-- Every unloaded road step can stay H through to the top.
for g=2,7 do
 m=motor(g,2);m.vehicle.speed=({3.4,5.4,7.8,10.4,14.2,19,25.9})[g];up(m);run(m,8)
 check(m.gear==g+1 and m.activeGearGroupIndex==2,'road H path '..g)
end
-- Full-load observed 5H does not get an unsupported upshift.
m=motor(5,2);m.vehicle.speed=11;m.vehicle.limit=12.2;m.rpm=1900;m.vehicle.spec_AdvancedDamageSystem.dynamicMotorLoad=1.01
run(m,80);check(m.gear==5 and m.activeGearGroupIndex==2,'full load holds 5H')
-- Group must not change during a main gear's neutral interval.
m=motor(3,2);m.vehicle.limit=12.2;m.vehicle.speed=7.8;m.vehicle.spec_AdvancedDamageSystem.dynamicMotorLoad=.72
up(m);check(m.targetGear==4 and m.activeGearGroupIndex==2 and m.gearChangeTimer==350,'3H to4L keeps H during opening')
local applies=m.applied or 0;tick(m,200);check(m.gear==0 and m.activeGearGroupIndex==2,'no early PS apply in neutral')
tick(m,151);check(m.gear==4 and m.activeGearGroupIndex==1,'coordinated 4L engagement')
check(m.applied==applies+1,'single native apply, no recursive early clutch engagement')
-- Requested reduction with a veto must not create 8H out of 8L.
m=motor(8,1);m.vehicle.speed=11;m.rpm=1000;m.vehicle.spec_AdvancedDamageSystem.dynamicMotorLoad=.9;m.veto=true
run(m,40);check(m.gear==8 and m.activeGearGroupIndex==1 and m.groupEvents==nil,'veto leaves8L')
check(m.ursusAuto.pending==nil,'veto clears plan')
m.veto=false;up(m);check(m.activeGearGroupIndex==1,'accepted reduction waits for clutch')
run(m,8);check(m.gear==7 and m.activeGearGroupIndex==2,'loaded recovery reaches7H')
-- Native direction veto can be released for confirmed lugging, not upshifts.
m=motor(8,1);m.vehicle.speed=11;m.rpm=1000;m.vehicle.spec_AdvancedDamageSystem.dynamicMotorLoad=.9;m.allowGearChangeTimer=3000
up(m);check(m.targetGear==7 and m.allowGearChangeTimer==0,'loaded reduction releases direction veto')
-- Telemetry validity and limits, slipping is not reserve.
m=motor();m.vehicle.spec_AdvancedDamageSystem.dynamicMotorLoad=0/0;m.vehicle.speed=25.9;up(m);check(m.ursusAuto.source=='GIANTS','NaN ADS fallback')
m=motor();m.vehicle.spec_AdvancedDamageSystem=nil;m.nativeLoad=nil;run(m,40);check(m.gear==7,'missing load cannot upshift')
m=motor();m.vehicle.speed=25.9;m.vehicle.spec_wheels.wheels[3].physics.netInfo.slip=.5;run(m,40);check(m.gear==7,'rear slip blocks upshift')
m=motor(5,2);m.rpm=2200;m.vehicle.speed=14.2;m.vehicle.limit=8;run(m,50);check(m.gear==5,'work limit postshift rpm gate')
-- ADS respects fixed failure and delay, and failed main request does not apply H.
m=motor(8,1);m.vehicle.speed=32;m.vehicle.spec_AdvancedDamageSystem.activeEffects={POWERSHIFT_ENGAGEMENT_LAG_AND_HARSH_EFFECT={value=1}}
run(m,50);check(m.activeGearGroupIndex==1,'ADS hard lag blocks PS')
m=motor(8,1);m.vehicle.speed=32;m.vehicle.spec_AdvancedDamageSystem.activeEffects={GEAR_SHIFT_FAILURE_CHANCE={value=0,extraData={status='FAILED'}}}
run(m,50);check(m.activeGearGroupIndex==1,'ADS failed status blocks PS')
m=motor(8,1);m.vehicle.speed=32;m.vehicle.spec_AdvancedDamageSystem.activeEffects={POWERSHIFT_ENGAGEMENT_LAG_AND_HARSH_EFFECT={value=.5}}
for i=1,60 do
 tick(m)
 if m.ursusAdsPendingGroupUntil then
  local untilTime=m.ursusAdsPendingGroupUntil
  check(m.activeGearGroupIndex==1 and g_time<untilTime,'ADS waits before engagement')
  run(m,20);check(m.activeGearGroupIndex==2,'ADS lag eventually completes');break
 end
end
-- Braking/direction changes and manual mode invalidate old pending plans.
m=motor(3,2);m.vehicle.limit=12.2;m.vehicle.speed=7.8;m.vehicle.spec_AdvancedDamageSystem.dynamicMotorLoad=.72;up(m)
m.gearShiftMode=2;run(m,8);check(m.activeGearGroupIndex==2 and m.ursusAuto==nil,'manual cancels pending group')
m=motor(3,2);m.vehicle.limit=12.2;m.vehicle.speed=7.8;m.vehicle.spec_AdvancedDamageSystem.dynamicMotorLoad=.72;up(m)
m.currentDirection=-1;run(m,8);check(m.activeGearGroupIndex==2,'direction cancels pending group')
m=motor(8,1);m.vehicle.speed=32;for i=1,30 do tick(m,50,1,1) end;check(m.activeGearGroupIndex==1,'brake blocks PS upshift')
-- Recovery after a failed upshift remembers the candidate.
m=motor(5,1);m.vehicle.speed=11.3;m.vehicle.limit=12.2;m.vehicle.spec_AdvancedDamageSystem.dynamicMotorLoad=.5
for i=1,60 do tick(m);if m.activeGearGroupIndex==2 then break end end
check(m.activeGearGroupIndex==2,'reserve allows5H')
m.rpm=1200;m.vehicle.spec_AdvancedDamageSystem.dynamicMotorLoad=1.05
run(m,22);check(m.activeGearGroupIndex==1 and m.ursusAuto.failure~=nil,'failed5H remembered')
m.rpm=2200;run(m,45);check(m.activeGearGroupIndex==1,'no immediate retry under unchanged high load')
-- Reverse uses its actual ratio table and a conservative L start.
m=motor(1,2);m.currentDirection=-1;m.vehicle.speed=0;m.start=true;tick(m,50,-1,0)
check(m.gear==1 and m.activeGearGroupIndex==1,'reverse start L')
print('PASS: '..count..' transmission assertions')
