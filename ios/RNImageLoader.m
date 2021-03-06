//
//  RNImageLoader.m
//  RNGalleryManager
//
//  Created by Hristo Hristov on 21.01.18.
//  Copyright © 2018 Facebook. All rights reserved.
//

/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "RNImageLoader.h"
#import <Photos/Photos.h>

@implementation RNImageLoader

RCT_EXPORT_MODULE()

@synthesize bridge = _bridge;

#pragma mark - RCTImageLoader

- (BOOL)canLoadImageURL:(NSURL *)requestURL {
  
  if (![PHAsset class]) {
    return NO;
  }
  return [requestURL.scheme caseInsensitiveCompare:@"assets-library"] == NSOrderedSame;
  
}

- (RCTImageLoaderCancellationBlock)loadImageForURL:(NSURL *)imageURL size:(CGSize)size scale:(CGFloat)scale resizeMode:(RCTResizeMode)resizeMode progressHandler:(RCTImageLoaderProgressBlock)progressHandler partialLoadHandler:(RCTImageLoaderPartialLoadBlock)partialLoadHandler completionHandler:(RCTImageLoaderCompletionBlock)completionHandler {
  NSString *assetID = @"";
  PHFetchResult *results;
  if (!imageURL) {
    completionHandler(RCTErrorWithMessage(@"Cannot load a photo library asset with no URL"), nil);
    return ^{};
  } else {
    assetID = [imageURL absoluteString];
    results = [PHAsset fetchAssetsWithALAssetURLs:@[imageURL] options:nil];
  }
  if (results.count == 0) {
    NSString *errorText = [NSString stringWithFormat:@"Failed to fetch PHAsset with local identifier %@ with no error message.", assetID];
    completionHandler(RCTErrorWithMessage(errorText), nil);
    return ^{};
  }
  
  PHAsset *asset = [results firstObject];
  PHImageRequestOptions *imageOptions = [PHImageRequestOptions new];
  
  // Allow PhotoKit to fetch images from iCloud
  imageOptions.networkAccessAllowed = YES;
  
  if (progressHandler) {
    imageOptions.progressHandler = ^(double progress, NSError *error, BOOL *stop, NSDictionary<NSString *, id> *info) {
      static const double multiplier = 1e6;
      progressHandler(progress * multiplier, multiplier);
    };
  }
  
  // Note: PhotoKit defaults to a deliveryMode of PHImageRequestOptionsDeliveryModeOpportunistic
  // which means it may call back multiple times - we probably don't want that
  imageOptions.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
  
  BOOL useMaximumSize = CGSizeEqualToSize(size, CGSizeZero);
  CGSize targetSize;
  if (useMaximumSize) {
    targetSize = PHImageManagerMaximumSize;
    imageOptions.resizeMode = PHImageRequestOptionsResizeModeNone;
  } else {
    targetSize = CGSizeApplyAffineTransform(size, CGAffineTransformMakeScale(scale, scale));
    imageOptions.resizeMode = PHImageRequestOptionsResizeModeFast;
  }
  
  PHImageContentMode contentMode = PHImageContentModeAspectFill;
  if (resizeMode == RCTResizeModeContain) {
    contentMode = PHImageContentModeAspectFit;
  }
  
  PHImageRequestID requestID =
  [[PHImageManager defaultManager] requestImageForAsset:asset
                                             targetSize:targetSize
                                            contentMode:contentMode
                                                options:imageOptions
                                          resultHandler:^(UIImage *result, NSDictionary<NSString *, id> *info) {
                                            if (result) {
                                              completionHandler(nil, result);
                                            } else {
                                              completionHandler(info[PHImageErrorKey], nil);
                                            }
                                          }];
  
  return ^{
    [[PHImageManager defaultManager] cancelImageRequest:requestID];
  };
}

@end
