# TechSprint OpenStack automatizacija

CSV-driven Ansible deployment za Red Hat Academy OpenStack overcloud.

## Što stvara

- zaseban Keystone projekt i grupu za svakog developera
- jednog Team Lead korisnika i centralni jump host
- izoliranu Neutron mrežu, subnet i router po developeru
- dvije Moodle aplikacijske VM instance i jednu DB VM po developeru
- flavor s 2 vCPU i 4 GB RAM-a
- drugi Cinder disk za svaku VM instancu
- interni Octavia load balancer s dvije backend instance
- privatni Swift container za Moodle datoteke
- Manila CephFS share za backup
- samo jedan floating IP, na Team Lead jump hostu
- oznake `project=techsprint` i `environment=testing`

## Pokretanje na director VM-u

```bash
source ~/overcloudrc
unzip techsprint-openstack.zip
cd techsprint-openstack
chmod +x deploy-openstack.sh
./deploy-openstack.sh /putanja/users.existing.csv
```

U paketu je već uključena kopija dostavljenog CSV-a, pa se može pokrenuti i ovako:

```bash
./deploy-openstack.sh ./users.csv
```

CSV koristi postojeći format:

```csv
ime;prezime;rola;upn;objectId
Ivan;Vrabac;devops_lead;lead.korisnik@algebra.hr;...
Mario;Nikolis;developer;prvi.developer@algebra.hr;...
Ivan;Majpruz;developer;drugi.developer@algebra.hr;...
```

`objectId` je Azure-specifičan i namjerno se zanemaruje.

## Tajne

Lozinke i SSH privatni ključ stvaraju se u `runtime/`. Ta je mapa u `.gitignore` i ne smije se commitati. Ponovno pokretanje koristi iste lokalne tajne i ne mijenja postojeće korisničke lozinke.

## Važno

Ovaj paket je prilagođen inventuri laboratorija:

- OpenStack CLI 4.0.0
- Ansible 2.9.13
- vanjska mreža `provider-datacentre`
- slike `rhel8`, `rhel8-web`, `rhel8-db`
- Cinder tip `tripleo`
- Manila backend `cephfs`
- Octavia provider `amphora`

Prvo stvarno pokretanje treba pratiti. Ako Academy slika nema pristup RHEL paketima ili Moodle downloadu, infrastruktura će svejedno nastati, a cloud-init bootstrap ćemo prilagoditi bez ponovnog stvaranja cijelog clouda.

Mermaid izvori za obavezne dijagrame nalaze se u `docs/openstack-architecture.mmd` i `docs/openstack-iam.mmd`.
