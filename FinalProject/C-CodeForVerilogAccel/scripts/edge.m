lenna = int8(rgb2gray(imread('Lenna.png')));
imshow(lenna);
Tx = int8([-1 -2 -1; 0 0 0; 1 2 1]);
Ty = Tx';
[xSize, ySize] = size(lenna);

for i = 2:xSize-1
    for j = 2:ySize-1
        tmp = lenna(i-1:i+1,j-1:j+1);
        xVal = sum(sum(tmp .* Tx));
        yVal = sum(sum(tmp .* Ty));
        outbuf(i,j) = abs(xVal) + abs(yVal);
    end
end

outbuf = uint8(outbuf);
imshow(outbuf);