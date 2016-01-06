[![Build Status](https://travis-ci.org/edk/transcode_service.svg?branch=master)](https://travis-ci.org/edk/transcode_service)

# README

This is an api-only app (using rails-api) to provide a video transcoding service for
[TribalKnowNow](https://github.com/edk/tribalknow)

It uses ffmpeg (via the paperclip-av-transcoder gem) or the AWS Elastic Transcoding service.

It also needs two sets of S3 credentials for Elastic Transcoder user.  One S3 bucket is where
the video assets from the TKN are stored.  The other bucket is where this service stores the
assets for use by AWS.  In my use-case, the S3 access needs to be different.


