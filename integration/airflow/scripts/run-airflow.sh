#!/usr/bin/env bash

set -e

project_root=$(git rev-parse --show-toplevel)
cd "${project_root}"/integration/

rm -rf ./python
cp -R ../client/python ./python
if [ ! -d "./sql/target/wheels" ]; then
  docker run -it --rm -v $PWD/sql:/code quay.io/pypa/manylinux2014_x86_64 bash -c 'cd /code; bash script/build.sh'
fi
mkdir -p target/wheels && cp -R sql/target/wheels target
docker build -f airflow/Dockerfile.tests -t openlineage-airflow-base .

# maybe overkill
OPENLINEAGE_AIRFLOW_WHL=$(docker run openlineage-airflow-base:latest sh -c "ls /whl/openlineage*.whl")

# Add revision to requirements.txt
cat > airflow/requirements.txt <<EOL
${OPENLINEAGE_AIRFLOW_WHL}
EOL

mkdir -p airflow/scripts/airflow/logs
chmod a+rwx -R airflow/scripts/airflow/logs

docker-compose -f airflow/scripts/docker-compose.yml down
docker-compose -f airflow/scripts/docker-compose.yml up --build --force-recreate --abort-on-container-exit airflow_init postgres
docker-compose -f airflow/scripts/docker-compose.yml up --build --scale airflow_init=0
