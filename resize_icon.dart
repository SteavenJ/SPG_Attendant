import 'dart:io';
import 'package:image/image.dart';

void main() {
  final imageBytes = File('IKN 2024 PNG.png').readAsBytesSync();
  final image = decodeImage(imageBytes)!;
  
  // Find the longest side
  final int size = image.width > image.height ? image.width : image.height;
  
  // Add 30% padding so the logo isn't touching the edges
  final int paddedSize = (size * 1.3).toInt();

  // Create a new empty image (transparent background)
  final paddedImage = Image(width: paddedSize, height: paddedSize, numChannels: 4);
  // Fill with white if the logo is dark, but transparent is safer
  
  // Draw the original image onto the center of the new image
  final dstX = (paddedSize - image.width) ~/ 2;
  final dstY = (paddedSize - image.height) ~/ 2;
  
  compositeImage(paddedImage, image, dstX: dstX, dstY: dstY);

  File('assets/icon.png').writeAsBytesSync(encodePng(paddedImage));
  print('Icon successfully resized and padded!');
}
