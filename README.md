# OCHaCafe Season8 #5 - Kubernetesで構築するIaaS基盤

## ディレクトリ構成

```sh
.
├── prepare
│   ├── snapshot.yaml
│   └── storageclass.yaml
├── README.md
├── script
│   └── ping.sh
├── templates
│   ├── common-preferences-bundle-v1.0.0.yaml
│   └── common-templates.yaml
└── vms
    ├── simple_demo.yaml
    └── vm_demo.yaml

4 directories, 8 files
```

## OKEとminikubeのプロビジョニング

### OKE

OKEのプロビジョニングはこちらを参考に実施してください。  
Worker Nodeのスペックは`VM.Standard.E5.Flex`シェイプで2oCPU、16GB RAMで作成してください。  
なお、CNIはFlannelで構築してください。  

### minikube

以下のコマンドを実行します。  

```sh
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
```

```sh
sudo install minikube-linux-amd64 /usr/local/bin/minikube && rm minikube-linux-amd64
```

```sh
minikube start --nodes=2 --cni=flannel
```

## KubeVirtのインストール

### OKE/minikube共通

#### KubeVirtのインストール

```sh
export VERSION=$(curl -s https://storage.googleapis.com/kubevirt-prow/release/kubevirt/kubevirt/stable.txt)
```

```sh
echo $VERSION
```

```sh
kubectl create -f https://github.com/kubevirt/kubevirt/releases/download/${VERSION}/kubevirt-operator.yaml
```

```sh
kubectl create -f https://github.com/kubevirt/kubevirt/releases/download/${VERSION}/kubevirt-cr.yaml
```

以下のコマンドを実行し、`Deployed`になればインストールは完了

```sh
$ kubectl get kubevirt.kubevirt.io/kubevirt -n kubevirt -o=jsonpath="{.status.phase}"
Deployed
```

virtctlをインストール

```sh
VERSION=$(kubectl get kubevirt.kubevirt.io/kubevirt -n kubevirt -o=jsonpath="{.status.observedKubeVirtVersion}")
ARCH=$(uname -s | tr A-Z a-z)-$(uname -m | sed 's/x86_64/amd64/') || windows-amd64.exe
```

```sh
echo ${ARCH}
```

```sh
curl -L -o virtctl https://github.com/kubevirt/kubevirt/releases/download/${VERSION}/virtctl-${VERSION}-${ARCH}
```

```sh
chmod +x virtctl
```

```sh
sudo install virtctl /usr/local/bin
```

#### minikubeのみ

nested virtualizationを有効化

```sh
kubectl -n kubevirt patch kubevirt kubevirt --type=merge --patch '{"spec":{"configuration":{"developerConfiguration":{"useEmulation":true}}}}'
```

#### VolumeSnapshotClass/VolumeSnapshotのインストール

```sh
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshotclasses.yaml
```

```sh
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshots.yaml
```

#### OKEのみ

##### VolumeSnapshotClass(OCI Block Volume Driver)のインストール

```sh
kubectl apply -f prepare/snapshot.yaml
```

#### minikubeのみ

##### VolumeSnapshotClass(NFS CSI Driver)のインストール

```sh
curl -skSL https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/v4.7.0/deploy/install-driver.sh | bash -s v4.7.0 --
```

```sh
kubectl apply -f prepare/nfs.yaml
```

#### LiveMigrationのFeature Gateを有効化

```sh
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: kubevirt-config
  namespace: kubevirt
  labels:
    kubevirt.io: ""
data:
  feature-gates: "LiveMigration"
EOF
```

## シンプルVMの作成とコンソール接続(OKE)

```sh
kubectl apply -f vms/simple_demo.yaml 
```

```sh
virtctl console testvm
```

## 実践！！KubeVirtのデモ - テンプレート/ストレージ/ヘルスチェック/SSH/cloud-init/CDI - (OKE)

### テンプレートの作成

```sh
kubectl apply -f templates/
```

### SSH接続用キーペアの作成

```sh
ssh-keygen
```

```sh
PUBKEY=`cat <作成した公開鍵のパス>`
```

```sh
sed -i "s%ssh-rsa.*%$PUBKEY%" vms/vm_demo.yaml
```

### VMの作成

```sh
kubectl apply -f vms/vm_demo.yaml 
```

### SSH接続用Seriviceの作成

```sh
virtctl expose vm ocha-vm --name=ocha-ssh --port=20222 --target-port=22 --type=NodePort
```

アサインされているパブリックIPを確認

```sh
kubect get svc ocha-ssh
```

```sh
ssh -i private.pem ubuntu@xxx.xxx.xxx.xxx
```



















