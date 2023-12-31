function [cmdl, c2f]= mk_grid_model(fmdl, xvec, yvec, zvec);
% MK_GRID_MODEL: Create reconstruction model on pixelated grid 
%  [cmdl,coarse2fine]= mk_grid_model(fmdl, xvec, yvec, zvec);
%
% Outputs:
%  cmdl - eidors reconstruction model (coarse model)
%  coarse2fine - c2f mapping to put onto fmdl (specify [] to not use)
%
% Inputs:
%  fmdl - fine model (forward model) to create coarse2fine mapping
%  xvec - x edges
%  yvec - y edges
%  zvec - z edges (optional - to create 3D model)
%
% if fmdl == [], then just create the grid model without c2f
%
% See also MK_COARSE_FINE_MAPPING, MK_PIXEL_SLICE
%
% Example: for constructing an inverse model
%  grid{1}= linspace(-2,2,20);     % x grid
%  grid{2}= linspace(-0.5,+0.5,5); % y grid
%  grid{3}= linspace(-2, 0,20);    % z grid
%  imdl = select_imdl( fmdl, {'Basic GN dif'});
%  [imdl.rec_model,imdl.fwd_model.coarse2fine]= mk_grid_model(fmdl,grid{:});
%
% ISSUES:
%  Ensure that grids are defined from smallest to largest

% (C) 2008 Andy Adler. License: GPL version 2 or version 3
% $Id: mk_grid_model.m 5902 2019-02-04 10:18:28Z aadler $

if ischar(fmdl) && strcmp(fmdl,'UNIT_TEST'); do_unit_test; return; end


if nargin == 3
   cmdl = mk_2d_grid(xvec,yvec);
elseif nargin ==4
   cmdl = mk_3d_grid(xvec,yvec,zvec);
else
   error('check nargin');
end

% this had too many side effects
cmdl = set_pixel_pos(cmdl,xvec,yvec);% same for 2d and 3d

% put in the centre (or near it)
ctr = ones(num_nodes(cmdl),1)*mean(cmdl.nodes);
dctr= sum( (cmdl.nodes - ctr).^2, 2);
[jnk, c_idx] = min(dctr);
cmdl.gnd_node = c_idx(1);

if ~isempty( fmdl)
    if size(fmdl.nodes,2) == 2
        assert(nargin==3);
        c2f= calc_c2f_2d( fmdl, xvec, yvec);
        
    else
        if nargin == 3
            % here we could incorporate z_depth
            zvec = [ min(fmdl.nodes(:,3)) - 1; max(fmdl.nodes(:,3))+1 ];
            tmp = mk_3d_grid(xvec,yvec,zvec);
        elseif nargin == 4
            tmp = cmdl;
        end
        c2f = mk_grid_c2f(fmdl,tmp);
    end
end

cmdl.normalize_measurements = 0;% @eidors_default;
cmdl.solve =      @eidors_default;
cmdl.system_mat = @eidors_default;
cmdl.jacobian   = @eidors_default;


function c2f= calc_c2f_2d( fmdl, xvec, yvec);
   nef= size( fmdl.elems,1);
   c2f= sparse(nef,0);
   mdl_pts = interp_mesh( fmdl, 3);
   x_pts = squeeze(mdl_pts(:,1,:));
   y_pts = squeeze(mdl_pts(:,2,:));
   for yi= 1:length(yvec)-1
         in_y_pts = y_pts >= yvec(yi) & y_pts < yvec(yi+1);
      for xi= 1:length(xvec)-1
          in_x_pts =  x_pts >= xvec(xi) & x_pts < xvec(xi+1);
          in_pts = mean( in_y_pts & in_x_pts , 2);
          c2f = [c2f,sparse(in_pts)];
      end
   end

function c2f= calc_c2f_3d( fmdl, xvec, yvec, zvec);
%  c2f= mk_coarse_fine_mapping( fmdl, cmdl);
   nef= size( fmdl.elems,1);
%  c2f= sparse(nef,0);
   c2fiidx= [];
   c2fjidx= [];
   c2fdata= [];
   jidx= 0;
   mdl_pts = interp_mesh( fmdl, 3);
   x_pts = squeeze(mdl_pts(:,1,:));
   y_pts = squeeze(mdl_pts(:,2,:));
   z_pts = squeeze(mdl_pts(:,3,:));
   
   in_x_pts = calc_in_d_pts( x_pts, xvec);
   in_y_pts = calc_in_d_pts( y_pts, yvec);
   in_z_pts = calc_in_d_pts( z_pts, zvec);

   for zi= 1:length(zvec)-1
      for yi= 1:length(yvec)-1
             in_yz_pts = in_y_pts{yi} & in_z_pts{zi};
         for xi= 1:length(xvec)-1
             in_pts = mean( in_x_pts{xi} & in_yz_pts, 2);
             % c2f = [c2f,sparse(in_pts)];
             [ii,jj,vv] = find(in_pts);
             c2fiidx= [c2fiidx;ii];
             c2fjidx= [c2fjidx;jj+jidx]; jidx=jidx+1;
             c2fdata= [c2fdata;vv];
         end
      end
   end
   c2f= sparse(c2fiidx,c2fjidx,c2fdata, length(in_pts), jidx);

function cmdl= mk_2d_grid(xvec, yvec);
   xlen = length(xvec);
   ylen = length(yvec);
   cmdl= eidors_obj('fwd_model', ...
            sprintf('Grid model %d x %d', xlen, ylen) );

   [x,y]= ndgrid( xvec, yvec);
   cmdl.nodes= [x(:),y(:)];
   k= 1:xlen-1;
   elem_frac = [ k;k+1;k+xlen; ...
                 k+1;k+xlen;k+xlen+1];
   elem_frac= reshape(elem_frac, 3,[])';
   cmdl.elems=  [];
   for j=0:ylen-2
      cmdl.elems=  [cmdl.elems; elem_frac + xlen*j];
   end

   cmdl.boundary = find_boundary( cmdl.elems);

% assign one single parameter to each square element
   e= size(cmdl.elems,1);
   params= ceil(( 1:e )/2);
   cmdl.coarse2fine = sparse(1:e,params,1,e,max(params));


function cmdl= mk_3d_grid(xvec, yvec, zvec);
   xlen = length(xvec);
   ylen = length(yvec);
   zlen = length(zvec);
   cmdl= eidors_obj('fwd_model', ...
            sprintf('Grid model %d x %d x %d', xlen, ylen, zlen) );

   [x,y,z]= ndgrid( xvec, yvec, zvec);
   cmdl.nodes= [x(:),y(:),z(:)];
   k= 1:xlen-1;
   ac = xlen; up = xlen*ylen; % accross vs up
   elem_frac = [ k;     k+1 ;  k+ac;   k+up;  ...
                 k+1;   k+ac;  k+up;   k+up+1; ...
                 k+ac;  k+up;  k+up+1; k+up+ac; ...
                 k+1;   k+ac;  k+ac+1; k+up+1; ...
                 k+ac;  k+ac+1;k+up+1; k+up+ac; ...
                 k+ac+1;k+up+1;k+up+ac;k+up+ac+1];
   elem_frac= reshape(elem_frac, 4,[])';

   row_frac =  [];
   for j=0:ylen-2
      row_frac=  [row_frac; elem_frac + ac*j];
   end

   cmdl.elems=  [];
   for k=0:zlen-2
      cmdl.elems=  [cmdl.elems; row_frac + up*k];
   end

   cmdl.boundary = find_boundary( cmdl.elems);

% assign one single parameter to each square element
   e= size(cmdl.elems,1);
   params= ceil(( 1:e )/6);
   cmdl.coarse2fine = sparse(1:e,params,1,e,max(params));

function mdl = set_pixel_pos(mdl, xvec, yvec)
   x = xvec(1:end-1) + 0.5*diff(xvec);
   y = yvec(1:end-1) + 0.5*diff(yvec);
   y = y(end:-1:1); %get the medical orientation right
   mdl.mdl_slice_mapper.x_pts = x;
   mdl.mdl_slice_mapper.y_pts = y;
   
   
function in_d_pts = calc_in_d_pts( d_pts, dvec);
   l1dvec= length(dvec)-1;
   in_d_pts = cell(l1dvec,1);
   for i= 1:l1dvec
      in_d_pts{i} = d_pts >= dvec(i) & d_pts < dvec(i+1);
   end

function do_unit_test
imdl = mk_common_model('b2c2',16); imdl.hyperparameter.value = 1e-3;
img = mk_image(imdl,1);     vh= fwd_solve(img);
img.elem_data([51,23])=1.1; vi= fwd_solve(img);
subplot(221); show_fem(img);
subplot(222); show_fem(inv_solve(imdl, vh, vi));

grid = linspace(-1,1,33);
[imdl.rec_model, imdl.fwd_model.coarse2fine] = ...
     mk_grid_model( imdl.fwd_model, grid, grid );
subplot(223); show_fem(inv_solve(imdl, vh, vi));
hold on; hh=show_fem(img); set(hh,'FaceAlpha',0,'EdgeColor',[0,0,1]); hold off;

outside = find(sum(imdl.fwd_model.coarse2fine,1) < eps);
imdl.fwd_model.coarse2fine(:,outside) = [];
imdl.rec_model.coarse2fine(:,outside) = [];
rec_out = [2*outside-1,2*outside];
imdl.rec_model.coarse2fine(rec_out,:) = [];
imdl.rec_model.elems(rec_out,:) = [];
subplot(224); show_fem(inv_solve(imdl, vh, vi));
hold on; hh=show_fem(img); set(hh,'FaceAlpha',0,'EdgeColor',[0,0,1]); hold off;
