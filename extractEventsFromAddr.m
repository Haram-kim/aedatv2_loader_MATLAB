function [DVS,DVSTs,APS,APSTs,IMU,IMUTs]=extractEventsFromAddr(addr,Ts)
%function [DVS,DVSTs,APS,APSTs,IMU,IMUTs]=extractRetinaEventsFromAddr(addr,Ts)
% This code is for version 2 AER-DAT file format
% Especially, DAVIS240C
% extracts retina events from 32 bit addr vector.
%
% addr is mixture vector of event addresses, APS (gray frame) addresses, IMU addresses.
%
% DVS type - type = 0
% DVS = [x, y, pol] : addresses and spike ON/OFF polarity pol with pol=1 for ON and pol=-1 for OFF
% DVSTs : DVS timestamp correspond to index of the DVS
%
% APS type - type = 1, subtype < 2 
% APS(u, v, frame_index) : pixel intensity of u, v positions of frame
% number frame_index, NEED TO BE NORMALIZED
% APSTs : APS timestamp correspond to index of the middle pixel
%
% IMU type - type = 1, subtype = 3 
% IMU = [Accel x, y, z, Gyro x, y, z, temperature]
% IMUTs : APS timestamp correspond to index of the IMU
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%               extractEventsFromAddr                                  %
%               2018-10-17           Haram Kim                         %
%               rlgkfka614@gmail.com                                   %
%               Seoul Nat'l Univ. ICSL                                 %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fprintf('\nextract event information from address \n');
tic;

retinaSizeX=240;
retinaSizeY=180;
framesize = retinaSizeX*retinaSizeY;
persistent  ADCmask subtypemask xmask ymask typemask IMUmask IMUtypemask...
    ADCshift subtypeshift xshift yshift typeshift IMUshift IMUtypeshift
if isempty(xmask)
    % packet    = TyyyyyyyyyxxxxxxxxxxssAAAAAAAAAA for APS and DVS type
    %           = TtttIIIIIIIIIIIIIIIIss0000000000 for IMU type
    % T: type
    % y: y position
    % x: x position
    % s: sub-type
    % A: Analog to Digital Converter (only for APS type)
    % t: IMU sample type (Accel x,y,z, temperature, Gyro x,y,z)
    % I: IMU raw value
    % 0: Not used area
    
    ADCmask = hex2dec ('3FF'); % polarity is 2 bits ranging from bit 0-9
    % 2^0*1023  = 00000000000000000000001111111111
    subtypemask = hex2dec ('C00'); % polarity is 2 bits ranging from bit 10-11
    % 2^10*3    = 00000000000000000000110000000000
    xmask = hex2dec ('3FF000'); % x are 10 bits ranging from bit 12-21  
    % 2^12*1023 = 00000000001111111111000000000000
    ymask = hex2dec ('7FC00000'); % y are 9 bits ranging from bit 22-30  
    % 2^22*511  = 01111111110000000000000000000000
    typemask = hex2dec ('80000000'); % polarity is 2 bits ranging from bit 31
    % 2^31*1    = 10000000000000000000000000000000
    IMUmask = hex2dec ('FFFF000');
% 2^12*(2^16-1) = 00001111111111111111000000000000
    IMUtypemask = hex2dec ('70000000');
    % 2^28*7    = 01110000000000000000000000000000
    
    ADCshift = 0;
    subtypeshift = 10;    
    xshift = 12; % bits to shift x to right
    yshift = 22; % bits to shift y to right
    typeshift = 31;
    IMUshift = 12;
    IMUtypeshift = 28;
end

if nargin==0
    error('provide addresses as input vector');
end

type    = logical(bitshift(bitand(addr,typemask),-typeshift));
subtype = double(bitshift(bitand(addr,subtypemask),-subtypeshift));

DVStype = find(~type);
APStype = find(type&(subtype<2));
IMUtype = find(type&(subtype==3));

% DVS data read
if(size(DVStype,1)==0)
DVS     = [DVStype, DVStype, DVStype];
DVSTs   = DVStype;
else
    
x       = retinaSizeX-1-double(bitshift(bitand(addr(DVStype),xmask),-xshift)); % x addresses
y       = retinaSizeY-1-double(bitshift(bitand(addr(DVStype),ymask),-yshift)); % y addresses
pol     = -1+subtype(DVStype); % 1 for ON, -1 for OFF
DVS     = [x,y,pol];
DVSTs   = Ts(DVStype);
end
% APS data read
if(size(APStype,1)==0)
APS     = zeros(retinaSizeY,retinaSizeX,1);
APSTs   = Ts(APStype);
else
    
APS_x   = double(bitshift(bitand(addr(APStype),xmask),-xshift)); % x addresses
APS_y   = retinaSizeY-1-double(bitshift(bitand(addr(APStype),ymask),-yshift)); % y addresses
ADC     = double(bitshift(bitand(addr(APStype),ADCmask),-ADCshift));
APSctrl = subtype(APStype);
APSctrl_shift = [APSctrl(1); APSctrl(1:end-1)];
APSctrl_flip  = APSctrl - APSctrl_shift;

if(find(APSctrl_flip==1,1)==2*framesize+1)
    APSctrl_flip(1) = 1;
end
newAPS  = find(APSctrl_flip==1);
APSCluster  = zeros(size(APSctrl));
framelength = length(newAPS);
for iter_c = 1:framelength-1
    APSCluster(newAPS(iter_c):newAPS(iter_c+1)) = iter_c;
end
    APSCluster(newAPS(framelength-1):end) = framelength;

APS = zeros(retinaSizeY,retinaSizeX,framelength-1);
for iter_frame = 1:framelength-1
    SignalRead  = (APSCluster == iter_frame)&(APSctrl==1);
    ResetRead   = (APSCluster == iter_frame)&(APSctrl==0);
    APSframe    = zeros(retinaSizeY,retinaSizeX);
    % signal read + reset read == framesize*2 이면 reshape로 때려 넣기 
    if((length(SignalRead)+length(ResetRead))==2*framesize)
        APSframe    = reshape(-ADC(SignalRead)+ADC(ResetRead),retinaSizeY,retinaSizeX); 
    else
        APSframe(APS_x(SignalRead)*retinaSizeY +APS_y(SignalRead)+1)   = - ADC(SignalRead);
        APSframe(APS_x(ResetRead)*retinaSizeY +APS_y(ResetRead)+1)     = APSframe(APS_x(ResetRead)*180+APS_y(ResetRead)+1) + ADC(ResetRead);
    end
    APS(:,:,iter_frame)   = APSframe;
end

APSTs   = Ts(APStype);
APSTs   = APSTs(find(APSctrl_flip==1)+framesize/2);
end
% IMU data read
if(size(IMUtype,1)==0)
IMU     = [IMUtype, IMUtype, IMUtype, IMUtype ,IMUtype ,IMUtype ,IMUtype]; 
IMUTs   = Ts(IMUtype);
else
    
IMUStreamTs  = Ts(IMUtype);
IMUsampletype = double(bitshift(bitand(addr(IMUtype),IMUtypemask),-IMUtypeshift)); % y addresses
IMUsample = double(bitshift(bitand(addr(IMUtype),IMUmask),-IMUshift)); % y addresses
IMU_Ax  = IMUsampletype==0;
IMU_Ay  = IMUsampletype==1;
IMU_Az  = IMUsampletype==2;
IMU_Temp = IMUsampletype==3;
IMU_Gx  = IMUsampletype==4;
IMU_Gy  = IMUsampletype==5;
IMU_Gz  = IMUsampletype==6;

Accel_X = IMUsample(IMU_Ax);
Accel_Y = IMUsample(IMU_Ay);
Accel_Z = IMUsample(IMU_Az);
Temperature = IMUsample(IMU_Temp);
Gyro_X  = IMUsample(IMU_Gx);
Gyro_Y  = IMUsample(IMU_Gy);
Gyro_Z  = IMUsample(IMU_Gz);

% check packet loss, TODO: count 7 coincide timestamp 
% IMUTs_Ax = IMUStreamTs(IMU_Ax);
% IMUTs_Ay = IMUStreamTs(IMU_Ay);
% IMUTs_Az = IMUStreamTs(IMU_Az);
% IMUTs_Temp = IMUStreamTs(IMU_Temp);
% IMUTs_Gx = IMUStreamTs(IMU_Gx);
% IMUTs_Gy = IMUStreamTs(IMU_Gy);
% IMUTs_Gz = IMUStreamTs(IMU_Gz);

IMU     = [Accel_X, Accel_Y, Accel_Z, Gyro_X ,Gyro_Y ,Gyro_Z ,Temperature]; 
% This may occur error due to packet loss.
IMUTs   = IMUStreamTs(IMU_Ax);
end

fprintf('\nextractino takes %f seconds', toc);
% yyaxis left
% plot(Ts(APStype));
% yyaxis right
% plot(APSctrl_flip==1);

% plot(ADC); hold on;
% plot((x*180+y)/432);
% plot(APSctrl*300); hold off;
