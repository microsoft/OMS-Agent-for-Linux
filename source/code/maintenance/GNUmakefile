all:


clean:
	rm /var/opt/microsoft/omsagent/tmp/*
	rm /etc/opt/microsoft/omsagent/certs/oms.key
	rm /etc/opt/microsoft/omsagent/certs/oms.crt
	rm /etc/opt/microsoft/omsagent/conf/oms.conf

test:
	./omsadmin.sh -w 15b1d09f-7870-457d-818e-7aa0d75d7a8e -s dFUjETbH2q6nqiRCw7iiVI8l+Yzj7KQ0Ry5zicKU5zeSm5GNFE9/IvkqGFSa1PRjuElNPIGNB8VJVQuzR0js5w==
	./omsadmin.sh -b
	./omsadmin.sh -r