# OpenShift Service Mesh Labs

Prerequisites:
* You will have OpenShift Service Mesh operator installed on OpenShift
* Installed Service Mesh
* Configure `addmissionConfig` to enable automatic sidecar injection.
See more details here
https://docs.openshift.com/container-platform/3.11/servicemesh-install/servicemesh-install.html#updating-master-configuration

When you have your OpenShift Service Mesh installed on your OpenShift Container Platform. You will clone this repo for the labs below.

## Lab 1. Observability
1. Web UI

2. Grafanda: http://grafana-istio-system.<subdomain>
Prometheus: http://prometheus-istio-system.<subdomain>

3. Customer metrics:
cd ~/istio/istio-tutorial/
istioctl create -f istiofiles/recommendation_requestcount.yml -n istio-system
cat istiofiles/recommendation_requestcount.yml

On Prometheus: istio_requests_total{destination_service="recommendation.demo.svc.cluster.local"}

## Lab 2. Ingress walkthrough

## Lab 3. Smart Routing
1. show round robin for all pods

2. Apply all traffic to v1: oc apply -f virtual-service-all-v1.yaml -n bookinfo

3. Smart routing Route all to 50/50 v1&v3: oc replace -f virtual-service-reviews-50-v3.yaml

4. Apply user identity: oc replace -f virtual-service-reviews-jason-v2-v3.yaml -n bookinfo


## Lab 4. Canary

```
oc replace -f virtual-service-reviews-90-10.yaml -n bookinfo
oc replace -f virtual-service-reviews-80-20.yaml -n bookinfo
oc replace -f virtual-service-reviews-10-90.yaml -n bookinfo
oc replace -f  virtual-service-reviews-to-v2.yaml -n bookinfo
```

## Lab 5. Dark Launch/Mirroring
1. cd ../httpbin

2. Oc project httpbin

3. Run send traffic only to v1: ./route-rules-to-v1.sh
sentTraffic.sh  & versionV2logs.sh

4. Apply mirror virtual service rule
`oc apply -f virtual-service-mirror.yaml -n httpbin`

5. sentTraffic.sh  & versionV2logs.sh


## Lab 6. Fault injection
1. Cleanup bookinfo/review

2. Oc project bookinfo

3. Check the productpage is working around v1-v3

4. 	Cd ~/bookinfo
```
	kubectl apply -f virtual-service-all-v1.yaml -n bookinfo
 	kubectl apply -f virtual-service-reviews-test-v2.yaml -n bookinfo
```

5. Login bookinfo app with user jason (no delay)
	>> logout
	`kubectl apply -f virtual-service-ratings-test-delay.yaml -n bookinfo`

   Login bookinfo app with user jason (delay)

6. clean up:
```
kubectl delete -f virtual-service-ratings-test-delay.yaml -n bookinfo
kubectl delete -f virtual-service-reviews-test-v2.yaml -n bookinfo
kubectl delete -f virtual-service-all-v1.yaml -n bookinfo
```
## Lab 7. Request timeout

1. Make sure rules are cleaned for bookinfo app

2. Oc project bookinfo

3. Check the productpage is working with v1-v3

4. Cd ~/bookinfo

```
kubectl apply -f virtual-service-all-v1.yaml
kubectl apply -f request-timeout-route-to-v2.yaml -n bookinfo
kubectl apply -f  request-timeout-add-delay-to-rating.yaml -n bookinfo
```
5. load productpage and notice delay
`kubectl apply -f request-timeout-add-timeout.yaml -n bookinfo`

6. load productpage, returns in about 1 second, instead of 2, and the reviews are unavailable.

7. cleanup
`kubectl delete -f virtual-service-all-v1.yaml -n bookinfo`

## Lab 8. Circuit Breaker
(https://github.com/redhat-developer-demos/istio-tutorial/blob/master/documentation/modules/ROOT/pages/5circuit-breaker.adoc)

1. oc project demo

2. V2 is a slower service
```
  oc apply -f demo-destination-mtls.yaml -n demo
	oc apply -f virtual-service-recommendation-v1_and_v2_50_50.yml -n demo
  ```
3. Run script ~/istio/istio-tutorial/scripts/cb1.sh >> see the v2 is slower

4. But suppose that in a production system this 3s delay was caused by too many concurrent requests to the same instance/pod. We don’t want multiple requests getting queued or making the instance/pod even slower. So we’ll add a circuit breaker that will open whenever we have more than 1 request being handled by any instance/pod.

	`oc replace -f destination-rule-recommendation_cb_policy_version_v2.yml -n demo`

5. Run script ~/istio/istio-tutorial/scripts/cb1.sh
You can run siege multiple times, but in all of the executions you should see some 503 errors being displayed in the results. That’s the circuit breaker being opened whenever Istio detects more than 1 pending request being handled by the instance/pod.

6. Clean up:
```
oc delete -f destination-rule-recommendation_cb_policy_version_v2.yml  -n demo
oc delete -f  virtual-service-recommendation-v1_and_v2_50_50.yml -n demo
Pool rejection
oc apply -f demo-destination-mtls.yaml -n demo
oc apply -f virtual-service-recommendation-v1_and_v2_50_50.yml -n demo
```

7. Scale up v2
`oc scale dc recommendation-v2 --replicas=2  -n demo`

8. Go to one of the pod terminal and type
`curl localhost:8080/misbehave`

9. Run script run-demo.sh >> 503 from miss behave pod
`oc replace -f destination-rule-recommendation_cb_policy_pool_ejection.yml -n demo`

10. Run script run-demo.sh >> less 503 error

11. Ultimate resilience with retries, circuit breaker, and pool ejection
we can combine multiple Istio capabilities to achieve the ultimate backend resilience:

  * Circuit Breaker to avoid multiple concurrent requests to an instance;

  * Pool Ejection to remove failing instances from the pool of responding instances;

  * Retries to forward the request to another instance just in case we get an open circuit breaker and/or pool ejection;

By simply adding a retry configuration to our current virtualservice, we’ll be able to get rid completely of our `503`s requests.

`oc replace -f virtual-service-recommendation-v1_and_v2_retry.yml -n demo`

12. Run script run-demo.sh

13. cleanup

## Lab 9. Security
1. Run the following commands to show the pods in each namespace
```
oc project test-mls
oc get pods -n foo
oc get pods -n bar
oc get pods -n legacy
```
```
kubectl exec $(kubectl get pod -l app=sleep -n bar -o jsonpath={.items..metadata.name}) -c sleep -n bar -- curl http://httpbin.foo:8000/ip -s -o /dev/null -w "%{http_code}\n"
```

```
for from in "foo" "bar" "legacy"; do for to in "foo" "bar" "legacy"; do kubectl exec $(kubectl get pod -l app=sleep -n ${from} -o jsonpath={.items..metadata.name}) -c sleep -n ${from} -- curl http://httpbin.${to}:8000/ip -s -o /dev/null -w "sleep.${from} to httpbin.${to}: %{http_code}\n"; done; done
```
The non-Istio service, e.g sleep.legacy doesn’t have a sidecar, so it cannot initiate the required TLS connection to Istio services. As a result, requests from sleep.legacy to httpbin.foo or httpbin.bar will fail.

2. Check out the MeshPolicy
```
oc get meshpolicy
oc get meshpolicy default -o yaml
```
This policy specifies that all workloads in the mesh will only accept encrypted requests using TLS. As you can see, this authentication policy has the kind: MeshPolicy. The name of the policy must be default, and it contains no targets specification (as it is intended to apply to all services in the mesh).

## Lab 10. Egress Traffic
1. `oc project egress`

2. Web UI >> Egress project

3. Got to sleep pod terminal
```
curl http://httpbin.org/headers
curl https://www.google.com
time curl -o /dev/null -s -w "%{http_code}\n" http://httpbin.org/delay/5
```
4. Apply time out: ./set-timeout-to-external.sh

5. run: time curl -o /dev/null -s -w "%{http_code}\n" http://httpbin.org/delay/5
