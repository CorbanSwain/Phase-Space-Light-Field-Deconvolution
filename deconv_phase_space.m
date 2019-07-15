function Output=deconv_phase_space(LF)
% Deconvolution the light field data in phase space 
%% Input:
% @LF: input single snapshot image by Light field camera 
%
% Ouput: the super resolution image by deconvolution  
%
% The Code is created based on the method described in the following paper 
%        ZHI LU, JIAMIN WU, HUI QIAO and YOU ZHOU .etc,
%        Phase-space deconvolution for light field microscopy
%        Optics Express, 2019. 

% Author: ZHI LU (luz18@mails.tsinghua.edu.cn)
% Date  : 05/21/2019

%% Pre-processing
% Realignment the LF image into phase space
load('PSF/Phase_space_psf.mat');
Nnum=size(H,3);
LR_phase_space=zeros(size(LF,1)/Nnum,size(LF,2)/Nnum,Nnum,Nnum);
for i=1:Nnum
    for j=1:Nnum
        LR_phase_space(:,:,i,j)=LF(i:Nnum:end,j:Nnum:end);
    end
end
phase_space = zeros( size(LF,1),size(LF,2),Nnum,Nnum );
for i = 1:Nnum
    for j = 1:Nnum
        phase_space(:,:,i,j) = imresize(LR_phase_space(:,:,i,j),[size(LF,1),size(LF,2)],'cubic');
    end
end
phase_space(phase_space<0)=0;
% Filter
x=-fix(size(phase_space,1)/2):fix(size(phase_space,1)/2);
[xx,yy]=meshgrid(x,x);
cut_off_freq=10;
sub_aperture_filter=zeros(size(phase_space,1),size(phase_space,2));
sub_aperture_filter(xx.^2+yy.^2 <= cut_off_freq^2)=1;
for i=1:Nnum
    for j=1:Nnum      
        phase_space_f_with_filter=fftshift(fft2(squeeze(phase_space(:,:,i,j)))).*sub_aperture_filter;
        phase_space_with_filter(:,:,i,j)=abs( ifft2(ifftshift(phase_space_f_with_filter)) );
    end
end
phase_space=phase_space_with_filter;
phase_space(phase_space<0)=0;

% Weights for every iteration
weight=squeeze(sum(sum(sum(H,1),2),5));
weight(find(isnan(weight))) = 0;
weight=weight./sum(weight(:));
weight=weight-min(weight(:));
weight(weight<0.00938)=0;
weight=weight.*80;

%% Deconvolution
maxIter=1;

% Initialization
Xguess=ones(size(LF,1),size(LF,2),size(H,5));
Xguess=Xguess./sum(Xguess(:)).*sum(LF(:));
Htf=zeros( size(LF,1),size(LF,2) , size(H,5) , Nnum ,Nnum );
for u=1:Nnum
    for v=1:Nnum
        if weight(u,v)==0
            continue;
        else
            Htf(:,:,:,u,v)= backwardProject_phase_space(squeeze(Ht(:,:,u,v,:)), ones( size(LF) ) );
        end
    end
end

% Ptychographic order
index1=[1,1,1,1,1,1,1,1,1,1,1,1,1,2,3,4,5,6,7,8,9,10,11,12,13,13,13,13,13,13,13,13,13,13,13,13,13,12,11,10,9,8,7,6,5,4,3,2,2,2,2,2,2,2,2,2,2,2,2,3,4,5,6,7,8,9,10,11,12,12,12,12,12,12,12,12,12,12,12,11,10,9,8,7,6,5,4,3,3,3,3,3,3,3,3,3,3,4,5,6,7,8,9,10,11,11,11,11,11,11,11,11,11,10,9,8,7,6,5,4,4,4,4,4,4,4,4,5,6,7,8,9,10,10,10,10,10,10,10,9,8,7,6,5,5,5,5,5,5,6,7,8,9,9,9,9,9,8,7,6,6,6,6,7,8,8,8,7,7];
index2=[1,2,3,4,5,6,7,8,9,10,11,12,13,13,13,13,13,13,13,13,13,13,13,13,13,12,11,10,9,8,7,6,5,4,3,2,1,1,1,1,1,1,1,1,1,1,1,1,2,3,4,5,6,7,8,9,10,11,12,12,12,12,12,12,12,12,12,12,12,11,10,9,8,7,6,5,4,3,2,2,2,2,2,2,2,2,2,2,3,4,5,6,7,8,9,10,11,11,11,11,11,11,11,11,11,10,9,8,7,6,5,4,3,3,3,3,3,3,3,3,4,5,6,7,8,9,10,10,10,10,10,10,10,9,8,7,6,5,4,4,4,4,4,4,5,6,7,8,9,9,9,9,9,8,7,6,5,5,5,5,6,7,8,8,8,7,6,6,7];

% iterative ptychographic volume update
for i=1:maxIter
    tic;
    for u_2=1:13
        for v_2=1:13
            u=index1((u_2-1)*13+v_2);
            v=index2((u_2-1)*13+v_2);
            if weight(u,v)==0
                continue;
            else
                XguessBefore=Xguess;
                HXguess=forwardProject_phase_space(squeeze(H(:,:,u,v,:)), Xguess);            
                errorEM=squeeze(phase_space(:,:,u,v))./HXguess;
                errorEM(~isfinite(errorEM))=0;                
                XguessCor = backwardProject_phase_space(squeeze(Ht(:,:,u,v,:)),errorEM) ;               
                Xguess_add=XguessBefore.*XguessCor./squeeze(Htf(:,:,:,u,v));
                Xguess_add(find(isnan(Xguess_add))) = 0;
                Xguess_add(find(isinf(Xguess_add))) = 0;
                Xguess_add(Xguess_add<0 ) = 0;
                Xguess=Xguess_add.*weight(u,v)+(1-weight(u,v)).*XguessBefore;
                Xguess(Xguess<0) = 0;              
            end
        end
    end
    ttime1=toc;
    disp(['iter ',num2str(i),' | ',num2str(maxIter),', phase-space deconvolution took ',num2str(ttime1),' secs']);
end

%% Post-processing
Output=Xguess(Nnum*2+1:end-Nnum*2,Nnum*2+1:end-Nnum*2,6:end-5);
