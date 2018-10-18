file =  'C:\Users\Haram\Desktop\DAVIS\dataset\10sec.aedat';
maxEvents = 1e8;
startEvent = 1;

global updatedFilename;
if (~strcmp(file,updatedFilename))
    [addr,Ts]=loadaerdat(file, maxEvents, startEvent);
    [DVS,DVSTs,APS,APSTs,IMU,IMUTs]=extractEventsFromAddr(addr,Ts);
    DVSTs = double(DVSTs)*1e-6; % unit: second 
    APSTs = double(APSTs)*1e-6;
    IMUTs = double(IMUTs)*1e-6;
    TimeInterval = max([DVSTs; APSTs; IMUTs]) - min([DVSTs; APSTs; IMUTs]);
    InitialTime = min([DVSTs; APSTs; IMUTs]);
    updatedFilename = file;
end

%% show gray image
imageNum = size(APS,3);

for iter = 1:imageNum
    pause(0.1);
    figure(1);
    imshow(imresize(APS(:,:,iter),2),[]);
%     figure(2);
%     xlim = [-1 max(APSTs)+1];
%     plot(APSTs(1:iter), 1, '.k');
end

%% show IMU data
figure(3);
plot(IMUTs, IMU)

%% Event
Event = [DVS, DVSTs];
curTime = InitialTime;
dt = 0.1;
frame = zeros(180,240);
alpha = 50;
faderate = exp(-alpha*dt);

for time = InitialTime:dt:InitialTime+TimeInterval
    tempFrame = zeros(180,240);
    eventInterval = find((DVSTs>=time).*(DVSTs<(time+dt)));
    if(size(eventInterval,1)==0)
        continue;
    end
    EventIn = Event(eventInterval,:);
    polON = EventIn(:,3) == 1;
    polOFF = EventIn(:,3) == -1;
    frame = frame * faderate;
    tempFrame(EventIn(polON,1)*180 + EventIn(polON,2) + 1) =  exp(-alpha*(time+dt - EventIn(polON,4)));
    tempFrame(EventIn(polOFF,1)*180 + EventIn(polOFF,2) + 1) =  -exp(-alpha*(time+dt - EventIn(polOFF,4)));
    frame = frame + tempFrame;

    figure(5);
    imshow(imresize((frame+1)/2,2,'Nearest'));
%     imwrite((frame+1)/2,['C:\Users\Haram\Desktop\gif\event', num2str(time,'%06f'), '.png']);
%     imagesc(tempFrame);
    pause(0.1);
%     fprintf('timestamp: %f \n',time);
end

%% Event + Gray
Event = [DVS, DVSTs];
curTime = InitialTime;
dt = 0.02;
frame = zeros(180,240);
alpha = 50;
faderate = exp(-alpha*dt);
for iter = 2:imageNum
    time = APSTs(iter-1);
    time_dt = APSTs(iter);
    tempFrame = zeros(180,240);
    eventInterval = find((DVSTs>=time).*(DVSTs<(time_dt)));
    if(size(eventInterval,1)==0)
        continue;
    end
    EventIn = Event(eventInterval,:);
    polON = EventIn(:,3) == 1;
    polOFF = EventIn(:,3) == -1;
    frame = frame * faderate;
    tempFrame(EventIn(polON,1)*180 + EventIn(polON,2) + 1) =  exp(-alpha*(time_dt - EventIn(polON,4)));
    tempFrame(EventIn(polOFF,1)*180 + EventIn(polOFF,2) + 1) =  -exp(-alpha*(time_dt - EventIn(polOFF,4)));
    frame = frame + tempFrame;

    figure(5);
    imshow(imresize((APS(:,:,iter)/550)+(frame),2,'Nearest'));
%     imwrite((frame+1)/2,['C:\Users\Haram\Desktop\gif\event', num2str(time,'%06f'), '.png']);
%     imagesc(tempFrame);
    pause(0.1);
%     fprintf('timestamp: %f \n',time);
end

%% show Event image
Event = [DVS, DVSTs];
curTime = InitialTime;
dt = 0.02;
for time = InitialTime:dt:InitialTime+TimeInterval
    EventIn = Event((DVSTs>=time).*DVSTs<(time+dt),:);
    polON = EventIn(:,3) == 1;
    polOFF = EventIn(:,3) == -1;
    figure(4);
    plot3(EventIn(polON,1),EventIn(polON,2),EventIn(polON,4),'.r'); hold on;
    plot3(EventIn(polOFF,1),EventIn(polOFF,2),EventIn(polOFF,4),'.b');
end
hold off;

%% Time line
figure(1);  plot(DVSTs,DVSTs, '.b');hold on; plot(APSTs,APSTs,'*r'); hold off;