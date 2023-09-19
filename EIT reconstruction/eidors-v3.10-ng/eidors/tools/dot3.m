function d = dot3(a,b)
%CROSS3  3D cross parallel cross product
%  D = DOT3(A,B) calculates the dot product between rows of matrices A
%  and B, both of which must be Nx3. D is Nx1 such that 
%    C(i) = dot(A(i,:),B(i,:))
% but it is calculated faster.

% (C) 2013 Bartlomiej Grychtol. License: GPL version 2 or 3.
% $Id: dot3.m 4260 2013-06-24 15:17:15Z aadler $

d = sum(a.*b,2);
