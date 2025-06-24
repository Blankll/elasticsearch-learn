#!/usr/bin/env node
import * as ros from '@alicloud/ros-cdk-core';
import { RosCdkOssDeploymentStack } from '../lib/ros-cdk-oss-deployment-stack';

const app = new ros.App({outdir: './cdk.out'});
new RosCdkOssDeploymentStack(app, 'RosCdkOssDeploymentStack');
app.synth();