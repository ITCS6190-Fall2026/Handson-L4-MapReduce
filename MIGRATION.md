# Migration to the official Apache Hadoop image

**Not a student-facing file. Delete it once the migration is verified.**

The cluster moved off `bde2020/hadoop-*` (the big-data-europe images, archived and
read-only since 2021, shipping Hadoop 2.x/3.2.1) onto **`apache/hadoop:3`**, which is
published by the Apache Hadoop project itself and ships **Hadoop 3.3.6**.

## Files replaced

| File | Change |
| ---- | ------ |
| `docker-compose.yml` | rewritten for `apache/hadoop:3` |
| `hadoop.env` | **delete it** — replaced by `config` |
| `config` | new; the apache image reads `CORE-SITE.XML_*` style variables |
| `pom.xml` | Hadoop 3.2.1 → **3.3.6**, plus a Java 8 compiler target |
| `README.md` | every container path updated |

## What changed and why it matters

**Paths.** `HADOOP_HOME` is `/opt/hadoop`, not `/opt/hadoop-3.2.1`. Every `docker cp` and
`cd` in the old instructions pointed at a directory that does not exist in this image.

**The container runs as the `hadoop` user, not root.** The old steps copied the JAR and the
dataset into `/opt/hadoop-3.2.1/share/hadoop/mapreduce/` and later wrote job output back
into the same directory. That directory is root-owned here, so the write would fail. All
staging now happens in `/tmp`, which is world-writable, and this is the change most likely
to have saved a class-wide failure.

**Configuration mechanism.** The bde2020 images read `hadoop.env` with names like
`CORE_CONF_fs_defaultFS`. The apache image reads an env file where the variable name
encodes the target XML file: `CORE-SITE.XML_fs.defaultFS`. The two are not
interchangeable, which is why `hadoop.env` has to go rather than be edited.

**Java version.** The old `pom.xml` set no compiler target at all, so Maven emitted
bytecode for whatever JDK the student had. Anyone on a recent JDK would have got
`UnsupportedClassVersionError` at run time, after starting the cluster and loading data.
`maven.compiler.release` is now pinned to 8.

**Dependency scope.** `hadoop-common` and `hadoop-mapreduce-client-core` are now
`provided`, since the cluster supplies them at run time. `hadoop-minicluster` and `junit`
are gone: there are no test sources, and minicluster is a large download on every student's
first build.

**Topology.** NameNode, 3 DataNodes, ResourceManager, 2 NodeManagers, history server. The
old file had 3 NodeManagers; two is enough for this job and lighter on a laptop. Ports are
unchanged: 9870 NameNode, 8088 ResourceManager, 19888 job history.

**Replication is set to 3** in `config`, matching the three DataNodes and the lecture.
Drop it to 1 if the cluster is slow to stabilise on your machine.

## Test checklist

Work through the README as a student would, from a clean state:

```bash
docker compose down -v          # start from nothing
docker compose up -d
docker ps                       # 8 containers, all running
```

- [ ] <http://localhost:9870> shows the NameNode with **3 live DataNodes**
- [ ] <http://localhost:8088> shows the ResourceManager with **active nodes**
- [ ] `mvn clean package` succeeds and produces the JAR
- [ ] `docker cp` of the JAR and the input file to `/tmp` succeeds
- [ ] `docker exec -it resourcemanager bash` gives a shell
- [ ] `hadoop fs -mkdir -p /input/data` and `-put` succeed
- [ ] `hadoop fs -ls /input/data` lists the file
- [ ] the job runs to completion; map reaches 100% before reduce moves
- [ ] `hadoop fs -cat /output/*` shows counts, ordered by frequency descending
- [ ] `hdfs dfs -get /output /tmp/` succeeds **as the `hadoop` user**
- [ ] `docker cp resourcemanager:/tmp/output/.` brings the results out
- [ ] <http://localhost:19888> shows the finished job
- [ ] `docker compose down` stops everything cleanly

## Most likely to need adjustment

1. **`bash` may not be on the image.** If `docker exec -it resourcemanager bash` fails, try
   `sh`. The step is otherwise unaffected.
2. **Container start order.** DataNodes and NodeManagers can come up before the services
   they register with. `restart: on-failure` should settle it within a minute; if not, add
   healthchecks.
3. **Memory.** Eight JVMs is demanding on a laptop. Dropping to two DataNodes and one
   NodeManager is the first thing to cut, at the cost of the "3 live DataNodes" check.
4. **Replication warnings** while DataNodes are still registering are normal and clear on
   their own.

## Rollback

The previous `docker-compose.yml` and `hadoop.env` are in the repository's git history.
`git revert` the migration commit if you need the old cluster back before class.
