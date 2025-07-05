import * as ros from '@alicloud/ros-cdk-core';
import * as ossDeployment from '@alicloud/ros-cdk-ossdeployment';
import * as path from 'node:path';

export class RosCdkOssDeploymentStack extends ros.Stack {
  constructor(scope: ros.Construct, id: string, props?: ros.StackProps) {
    super(scope, id, props);
    new ros.RosInfo(this, ros.RosInfo.description, "This is the simple ros cdk app example.");
    // The code that defines your stack goes here
    const ossDeploymentId = 'si_auto_artifacts_code_deployment';

    new ossDeployment.BucketDeployment(
      this,
      ossDeploymentId,
      {
        sources: [ossDeployment.Source.asset(path.resolve(process.cwd(), 'sample.zip'), { deployTime: true })],
        destinationBucket: 'si-destination-bucket-test',
        timeout: 3000,
        logMonitoring: false,
        retainOnCreate: false,
      },
      true,
    );
  }
}
