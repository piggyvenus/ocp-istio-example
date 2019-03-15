kubectl delete virtualservice httpbin
kubectl delete destinationrule httpbin
kubectl delete deployment httpbin-v1 httpbin-v2 sleep
kubectl delete svc httpbin
oc delete all --all -n httpbin
