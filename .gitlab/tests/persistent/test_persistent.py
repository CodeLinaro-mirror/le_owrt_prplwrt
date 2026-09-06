import importlib.util
import json
import os
import re
import signal
import time
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
import yaml
from fake_broker import Broker

D=Path(__file__).resolve().parents[3]
SRC=Path(__file__).resolve().parent/'baseline'
spec=importlib.util.spec_from_file_location('policy',D/'.gitlab/scripts/persistent-policy.py')
policy=importlib.util.module_from_spec(spec);spec.loader.exec_module(policy)

def run(args,**kw):
    return subprocess.run(args,text=True,capture_output=True,**kw)

class RecipeTests(unittest.TestCase):
    def setUp(self):
        tmp=tempfile.TemporaryDirectory();self.addCleanup(tmp.cleanup)
        previous=Path.cwd();os.chdir(tmp.name);self.addCleanup(os.chdir, previous)
        self.recipe=Path('package/system/mtd');(self.recipe/'src').mkdir(parents=True)
        self.marker='include $(TOPDIR)/rules.mk\n$(eval $(call BuildPackage,mtd))\n'
        (self.recipe/'Makefile').write_text(self.marker)
        (self.recipe/'src/Makefile').write_text('CC = gcc\nobj = mtd.o\n')
        self.source=self.recipe/'src/mtd.c';self.source.write_text('int a;\n')

    def test_recipe_walks_past_source_makefile(self):
        self.assertEqual(policy.recipe(str(self.source)), str(self.recipe))

    def test_recipe_without_recipe_ancestor_is_fresh(self):
        (self.recipe/'Makefile').write_text('# BuildPackage in a source comment\n')
        with self.assertRaisesRegex(ValueError, 'missing package recipe'):
            policy.recipe(str(self.source))

    def test_recipe_rejects_shared_recipes_through_src(self):
        for marker in ('Build/InstallDev', 'HostBuild', 'KernelPackage'):
            with self.subTest(marker=marker):
                (self.recipe/'Makefile').write_text(self.marker+marker)
                with self.assertRaisesRegex(ValueError, 'dependency closure is not established'):
                    policy.recipe(str(self.source))

    def test_recipe_makefile_change_still_fresh(self):
        for path in (self.recipe/'Makefile', self.recipe/'src/Makefile'):
            with self.subTest(path=path):
                with self.assertRaisesRegex(ValueError, 'recipe definition, or shared input'):
                    policy.recipe(str(path))

class DraftTests(unittest.TestCase):
    def test_runner_ownership_and_rev_parse_diagnostic(self):
        script = (D/'.gitlab/scripts/persistent-build.sh').read_text()
        calls = re.findall(r'(?m)^.*\bgit .+$', script)
        self.assertEqual(calls[0], "git config --global --add safe.directory '*'")
        root_sync = script.split('root_sync() {', 1)[1].split('\n}\n', 1)[0]
        with tempfile.TemporaryDirectory() as tmp:
            # An isolated HOME has no safe.directory configuration. Simulate
            # the ownership rejection without requiring a root-owned fixture.
            env = {**os.environ, 'HOME': tmp, 'CI_PROJECT_DIR': tmp}
            stub = "git() { echo 'fatal: detected dubious ownership in repository' >&2; return 128; }\n"
            die = 'die() { echo "persistent: $*" >&2; exit 1; }\n'
            # Supply .git so git init does not mask the rev-parse fixture.
            Path(tmp, '.git').mkdir()
            result = run(['bash', '-c', 'set -e\n'+stub+die+'root_sync() {'+root_sync+'\n}\nroot_sync'], cwd=tmp, env=env)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('Cannot inspect Runner checkout: fatal: detected dubious ownership', result.stderr)
            self.assertNotIn('must have full history', result.stderr)

    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.t=Path(self.tmp.name);self.project=self.t/'project';self.project.mkdir()
        self.persist=self.t/'persist';self.slot=self.persist/'slots/0';self.slot.mkdir(parents=True)
        (self.slot/'.slot-id').write_text('0\n')
        self.bin=self.t/'bin';self.bin.mkdir();(self.t/'home').mkdir()
        self.env={**os.environ,'HOME':str(self.t/'home'),'PATH':str(self.bin)+':'+os.environ['PATH'],
                  'CI_PROJECT_DIR':str(self.project),'CI_PROJECT_ID':'1','CI_MERGE_REQUEST_IID':'2',
                  'CI_JOB_NAME':'build test x86_64 prpl security','CI_JOB_ID':'3','CI_BUILD_PROFILE':'x86_64 prpl security',
                  'PRPLOS_BUILDER_IMAGE_DIGEST':'sha256:'+'a'*64,'MOCK_LOG':str(self.t/'make.log')}
        self.env['PRPLOS_BUILDER_IMAGE']='registry.example/builder@'+self.env['PRPLOS_BUILDER_IMAGE_DIGEST']
        self.env['CI_JOB_IMAGE']=self.env['PRPLOS_BUILDER_IMAGE']
        self.socket=self.t/'broker.sock'
        for d in ['locks','trees','dl','ccache','meta','dl-slots/0']:(self.persist/d).mkdir(parents=True,exist_ok=True)
        for name in ['slot-0','registry','downloads']:(self.persist/'locks'/name).touch()
        self.broker=Broker(self.persist,self.socket);self.addCleanup(self.broker.close)
        for key in ['BUILD_CCACHE','CLEAN_BUILD','BUILD_CLEAN_LABEL','CLEAN_NO_CCACHE','CCACHE_DISABLE','MOCK_FAIL']:
            self.env.pop(key,None)
        for name in ['persistent-build.sh','persistent-policy.py','with-tree']:
            p=self.project/'.gitlab/scripts'/name;p.parent.mkdir(parents=True,exist_ok=True)
            # Simulate the two bind aliases using their single scratch directory.
            text=(D/'.gitlab/scripts'/name).read_text().replace('/run/prplos-persist/broker.sock',str(self.socket))
            text=text.replace('/build/prplos',str(self.slot/'prplos')).replace('/build/.slot-id',str(self.slot/'.slot-id'))
            text=re.sub(r'/dl(?=[/\s\"\']|$)',str(self.persist/'dl-slots/0'),text)
            text=text.replace('/ccache/',str(self.persist/'ccache')+'/')
            p.write_text(text)
        (self.project/'.gitlab/scripts/helpers.sh').write_text('section_start() { echo "section_start:$1"; }; section_end() { echo "section_end:$1"; }\n')
        (self.project/'profiles').mkdir();(self.project/'profiles/x86_64.yml').write_text('target: x86\n')
        (self.project/'feeds.conf.default').write_text('')
        recipe=self.project/'package/foo';recipe.mkdir(parents=True)
        (recipe/'Makefile').write_text('include $(TOPDIR)/rules.mk\n$(eval $(call BuildPackage,foo))\n');(recipe/'src.c').write_text('int a;\n')
        (self.project/'.gitignore').write_text('bin/\nlogs/\nfeeds/\n*hash-issues.patch\n.config\n.genconfig-state/\n')
        generator=self.project/'scripts/gen_config.py';generator.parent.mkdir()
        generator.write_text('''#!/usr/bin/env python3
# --incremental
import os,json,pathlib,subprocess
p=pathlib.Path; p('logs').mkdir(exist_ok=True); p('feeds').mkdir(exist_ok=True)
old=os.getenv('GENCONFIG_BASE_REV'); new=os.environ['CI_COMMIT_SHA']
paths=subprocess.check_output(['git','diff','--name-only',old,new],text=True).splitlines() if old else None
p('.config').write_text('CONFIG_TARGET_x86=y\\nCONFIG_PACKAGE_foo=y\\n')
p('logs/incremental-plan.json').write_text(json.dumps(dict(schema=1,phase='setup-complete',requires_full_rebuild=paths is None,root=dict(old_sha=old,new_sha=new,changed_paths=paths,dirty_paths=sorted(record[3:] for record in subprocess.check_output(['git','status','--porcelain','-uall','-z'],text=True).split('\\0') if record)),feeds=[])))
''');generator.chmod(0o755)
        for name,body in {
            'sudo':'#!/bin/sh\nexit 0\n',
            'ccache':'#!/bin/sh\nprintf "direct_cache_hit 10\\npreprocessed_cache_hit 2\\ncache_miss 1\\n"\n',
            'make':'''#!/usr/bin/env python3
import os,sys,pathlib
with open(os.environ['MOCK_LOG'],'a') as f:f.write(' '.join(sys.argv[1:])+'\\n')
if os.getenv('MOCK_TOOLS')=='1' and 'tools/tar/compile' in sys.argv: print('tools fixture failure');sys.exit(9)
if os.getenv('MOCK_HASH')=='1' and 'download' in sys.argv: pathlib.Path('package/foo/Makefile').write_text('checksum repair\\n')
if 'defconfig' in sys.argv:
 p=pathlib.Path('.config');p.write_text(p.read_text().replace('CONFIG_CCACHE=n', '# CONFIG_CCACHE is not set'))
if len(sys.argv)==3 and sys.argv[1]=='-j':
 if os.getenv('MOCK_FAIL')=='1': print('ERROR: package/foo failed to build.');sys.exit(7)
 pathlib.Path('bin').mkdir(exist_ok=True);pathlib.Path('bin/image').write_text(os.environ['CI_COMMIT_SHA'])
'''
        }.items():
            p=self.bin/name;p.write_text(body);p.chmod(0o755)
        run(['git','init','-q',str(self.project)],env=self.env,check=True)
        self.commit()

    def commit(self):
        run(['git','-C',str(self.project),'add','.'],env=self.env,check=True)
        run(['git','-C',str(self.project),'-c','user.name=Fixture','-c','user.email=fixture@example.invalid','-c','commit.gpgsign=false','commit','-qm','fixture'],env=self.env,check=True)
        self.env['CI_COMMIT_SHA']=run(['git','-C',str(self.project),'rev-parse','HEAD'],check=True).stdout.strip()

    def build(self,**env):
        r=run(['bash',str(self.project/'.gitlab/scripts/persistent-build.sh')],env={**self.env,**env})
        self.last=r
        return r

    def tree(self):return next((self.persist/'trees').iterdir())

    def test_cold_noop_package_clean_and_label(self):
        r=self.build();self.assertEqual(r.returncode,0,r.stderr)
        tree=self.tree();self.assertTrue((tree/'.persistent-success.json').exists())
        (tree/'bin/sentinel').write_text('keep')
        r=self.build();self.assertEqual(r.returncode,0,r.stderr);self.assertTrue((tree/'bin/sentinel').exists())
        (self.project/'package/foo/src.c').write_text('int b;\n');self.commit()
        r=self.build();self.assertEqual(r.returncode,0,r.stderr)
        self.assertIn('package/foo/clean',(self.t/'make.log').read_text());self.assertTrue((tree/'bin/sentinel').exists())
        r=self.build(BUILD_CLEAN_LABEL='1');self.assertEqual(r.returncode,0,r.stderr);self.assertFalse((tree/'bin/sentinel').exists())
        self.assertEqual(json.loads((self.project/'logs/build-metrics.json').read_text())['status'],'metrics-pending')

    def test_nested_source_clean_evidence(self):
        recipe=self.project/'package/system/mtd';(recipe/'src').mkdir(parents=True)
        (recipe/'Makefile').write_text('include $(TOPDIR)/rules.mk\n$(eval $(call BuildPackage,mtd))\n')
        (recipe/'src/Makefile').write_text('CC = gcc\nobj = mtd.o\n')
        (recipe/'src/mtd.c').write_text('int a;\n');self.commit()
        self.assertEqual(self.build().returncode, 0)
        (recipe/'src/mtd.c').write_text('int b;\n');self.commit()
        result=self.build();self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        tree=self.tree()
        # The consumer appends /clean; the plan and metrics record recipe dirs.
        self.assertEqual((tree/'logs/clean-plan.txt').read_text(), 'packages\npackage/system/mtd\n')
        metrics=json.loads((tree/'logs/build-metrics.json').read_text())
        self.assertEqual(metrics['clean_actions'], ['package/system/mtd'])
        self.assertTrue(metrics['tree_reused'])
        commands=(self.t/'make.log').read_text().splitlines()
        self.assertEqual(commands.count('package/system/mtd/clean'), 1)
        self.assertFalse((tree/'.build_failed').exists())
        self.assertFalse((self.project/'logs/incremental-escalation.json').exists())

    def test_profile_change_reuses_without_cleans(self):
        self.assertEqual(self.build().returncode, 0)
        (self.project/'profiles/x86_64.yml').write_text('target: x86\n# profile edit\n');self.commit()
        result=self.build();self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.tree()/'logs/clean-plan.txt').read_text().split(), ['packages'])
        metrics=json.loads((self.tree()/'logs/build-metrics.json').read_text())
        self.assertTrue(metrics['tree_reused'])
        # An empty plan has a trailing blank line; the shell skips it.
        self.assertFalse(any(metrics['clean_actions']))
        self.assertFalse(any(line.endswith('/clean') for line in (self.t/'make.log').read_text().splitlines()))

    def test_root_markers_before_generate_preserve_reuse(self):
        self.assertEqual(self.build().returncode, 0)
        tree = self.tree()
        (tree/'bin/sentinel').touch()
        for marker in ('.build_failed', 'rootfs-debug.tar.xz'):
            (tree/marker).touch()
        result = self.build()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue((tree/'bin/sentinel').exists())
        manifest = json.loads((tree/'logs/incremental-plan.json').read_text())
        self.assertEqual(manifest['root']['dirty_paths'], [])
        self.assertTrue(json.loads((tree/'logs/build-metrics.json').read_text())['tree_reused'])

    def test_real_gitignore_excludes_ci_products(self):
        (self.project/'.gitignore').write_bytes((D/'.gitignore').read_bytes())
        for marker in ('.build_failed', 'rootfs-debug.tar.xz'):
            (self.project/marker).touch()
            result = run(['git', 'check-ignore', marker], cwd=self.project)
            self.assertEqual(result.returncode, 0, marker)

    def test_failed_generator_restores_mirror_rewrite_and_status(self):
        (self.project/'feeds.conf.default').write_text('src-git packages https://git.openwrt.org/feed/packages.git\n')
        self.commit()
        original = (self.project/'feeds.conf.default').read_bytes()
        (self.project/'scripts/gen_config.py').write_text('#!/usr/bin/env python3\nraise SystemExit(91)\n')
        script = (D/'.gitlab/scripts/persistent-build.sh').read_text()
        generate = script.split('generate() {', 1)[1].split('\n}\n', 1)[0]
        for incremental in ('true', 'false'):
            shell = 'set -Eeuo pipefail\nprofiles=(x86_64)\n'
            shell += f'incremental_generator() {{ {incremental}; }}\n'
            shell += 'generate() {' + generate + '\n}\nif generate; then exit 0; else exit $?; fi\n'
            result = run(['bash', '-c', shell], cwd=self.project,
                         env={**self.env, 'scripts': str(self.project/'.gitlab/scripts')})
            self.assertEqual(result.returncode, 91, result.stderr)
            self.assertEqual((self.project/'feeds.conf.default').read_bytes(), original)

    def test_excludes_are_complete_and_idempotent(self):
        self.assertEqual(self.build().returncode, 0)
        exclude = self.tree()/'.git/info/exclude'
        expected = '/.persistent-*\n/.incomplete\n/.build_failed\n/rootfs-debug.tar.xz\n'
        self.assertEqual(exclude.read_text(), expected)
        self.assertEqual(self.build().returncode, 0)
        self.assertEqual(exclude.read_text(), expected)

    def test_unclassified_dirty_root_still_forces_fresh(self):
        self.assertEqual(self.build().returncode, 0)
        tree = self.tree()
        (tree/'include').mkdir()
        (tree/'include/kernel.mk').write_text('unexpected input\n')
        result = self.build()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        rejected = json.loads((self.project/'logs/incremental-escalation.json').read_text())
        self.assertIn('include/kernel.mk', rejected['root']['dirty_paths'])
        self.assertEqual(json.loads((tree/'logs/build-provenance.json').read_text())['clean_reason'], 'invalidation')

    def test_generator_failure_escalates_once_in_job(self):
        self.assertEqual(self.build().returncode, 0)
        tree = self.tree()
        (tree/'bin/sentinel').touch()
        generator = self.project/'scripts/gen_config.py'
        generator.write_text(generator.read_text().replace(
            '# --incremental', '# --incremental\nimport pathlib\nif pathlib.Path("bin/sentinel").exists(): raise SystemExit(91)'))
        self.commit()
        result = self.build()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse((tree/'bin/sentinel').exists())
        self.assertEqual(json.loads((tree/'logs/build-provenance.json').read_text())['clean_reason'], 'generator-failed')
        self.assertEqual(json.loads((tree/'logs/build-metrics.json').read_text())['clean_actions'], ['generator-failed'])
        self.assertEqual(result.stdout.count('section_start:gen-config'), 2)
        self.assertFalse((tree/'.build_failed').exists())
        self.assertTrue((tree/'.persistent-success.json').exists())

    def test_generator_failure_on_fresh_tree_is_fatal(self):
        self.assertEqual(self.build().returncode, 0)
        generator = self.project/'scripts/gen_config.py'
        generator.write_text('#!/usr/bin/env python3\n# --incremental\nraise SystemExit(91)\n')
        self.commit()
        result = self.build()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout.count('section_start:gen-config'), 2)
        self.assertTrue((self.tree()/'.build_failed').exists())
        self.assertFalse((self.tree()/'.persistent-success.json').exists())
        self.assertEqual(run(['git', 'diff', '--', 'feeds.conf.default'], cwd=self.tree()).stdout, '')

    def test_real_failure_is_cold_on_next_attach(self):
        self.assertEqual(self.build().returncode,0)
        r=self.build(MOCK_FAIL='1');self.assertEqual(r.returncode,7,r.stderr)
        tree=self.tree();(tree/'bin/sentinel').touch()
        self.assertIn(['DETACH','0','7','0'],self.broker.requests)
        self.assertEqual(self.build().returncode,0);self.assertFalse((tree/'bin/sentinel').exists())

    def test_deleted_recipe_and_global_inputs_fresh(self):
        r=self.build();self.assertEqual(r.returncode,0,r.stderr)
        tree=self.tree();(tree/'bin/sentinel').touch()
        (self.project/'package/foo/src.c').unlink();self.commit()
        r=self.build();self.assertEqual(r.returncode,0,r.stderr);self.assertFalse((tree/'bin/sentinel').exists())
        (tree/'bin/sentinel').touch();(self.project/'Makefile').write_text('# changed\n');self.commit()
        r=self.build();self.assertEqual(r.returncode,0,r.stderr);self.assertFalse((tree/'bin/sentinel').exists())

    def test_kernel_and_config_invalidation(self):
        r=self.build();self.assertEqual(r.returncode,0,r.stderr)
        tree=self.tree();(tree/'bin/sentinel').touch()
        patch=self.project/'target/linux/x86/patches/100-example.patch'
        patch.parent.mkdir(parents=True);patch.write_text('patch fixture\n');self.commit()
        r=self.build();self.assertEqual(r.returncode,0,r.stderr)
        self.assertNotIn('target/linux/clean',(self.t/'make.log').read_text())
        self.assertFalse((tree/'bin/sentinel').exists())
        r=self.build(CI_BUILD_CONFIG_EXTRA='+KERNEL_DEBUG_INFO');self.assertEqual(r.returncode,0,r.stderr)
        self.assertFalse((tree/'bin/sentinel').exists())

    def test_play_clean_no_ccache_and_legacy_generator(self):
        r=self.build();self.assertEqual(r.returncode,0,r.stderr)
        tree=self.tree();(tree/'bin/sentinel').touch()
        r=self.build(CLEAN_BUILD='1',CLEAN_NO_CCACHE='1');self.assertEqual(r.returncode,0,r.stderr)
        self.assertFalse((tree/'bin/sentinel').exists())
        self.assertIsNone(json.loads((self.project/'logs/build-metrics.json').read_text())['ccache_hits'])
        generator=self.project/'scripts/gen_config.py'
        generator.write_text(generator.read_text().replace('# --incremental','# legacy'));self.commit()
        (tree/'bin/sentinel').touch()
        r=self.build();self.assertEqual(r.returncode,0,r.stderr);self.assertTrue((tree/'bin/sentinel').exists())

    def test_build_ccache_disabled_keeps_tree_and_download_slot(self):
        # Any invocation, including stats, leaves evidence and fails the fixture.
        (self.bin/'ccache').write_text('#!/bin/sh\n touch "$MOCK_LOG.ccache"; exit 99\n')
        for attempt in range(2):
            r=self.build(BUILD_CCACHE='0', CI_BUILD_CONFIG_EXTRA='+CCACHE CONFIG_CCACHE_DIR="/wrong"')
            self.assertEqual(r.returncode,0,r.stderr)
            config=(self.tree()/'.config').read_text()
            self.assertIn('# CONFIG_CCACHE is not set',config)
            self.assertNotIn('CONFIG_CCACHE_DIR',config)
            self.assertIn(str(self.persist/'dl-slots/0'),config)
            metrics=json.loads((self.project/'logs/build-metrics.json').read_text())
            self.assertFalse(metrics['ccache_enabled'])
            for field in ('ccache_hits','ccache_misses','ccache_uncacheable'):
                self.assertIsNone(metrics[field])
            self.assertEqual(metrics['tree_reused'],bool(attempt))
            provenance=json.loads((self.project/'logs/build-provenance.json').read_text())
            self.assertEqual(provenance['build_ccache'],0)
            if attempt:self.assertTrue((self.tree()/'bin/sentinel').exists())
            (self.tree()/'bin/sentinel').touch()
        self.assertFalse((self.t/'make.log.ccache').exists())

    def test_image_mismatch_rejected_and_other_cache_family(self):
        r=self.build(CI_JOB_IMAGE='registry.example/builder:latest')
        self.assertNotEqual(r.returncode,0);self.assertIn('configured builder image',r.stderr)
        r=self.build(CI_BUILD_PROFILE='mtk_filogic prpl security')
        self.assertEqual(r.returncode,0,r.stderr)
        self.assertIn(str(self.persist/'ccache/other'),(self.tree()/'.config').read_text())

    def test_workflow_routing_and_label_snapshot(self):
        cfg=yaml.safe_load((D/'.gitlab-ci.yml').read_text())
        for source,labels,tag,clean in [('merge_request_event','build::clean','prplos-builder-persistent','1'),
                                       ('merge_request_event','build::cleaner','prplos-builder-persistent','0'),
                                       ('push','','firmware-builder','0'),('schedule','','firmware-builder','0')]:
            values=dict(cfg['variables'])
            if source=='merge_request_event':
                rule=cfg['workflow']['rules'][0 if 'build::clean' in labels.split(',') else 1]
                values.update(rule['variables'])
            else:
                values.update(cfg['workflow']['rules'][-1]['variables'])
            selected=values['BUILD_RUNNER_TAG']
            self.assertEqual((selected,values['BUILD_CLEAN_LABEL']),(tag,clean))

    def test_single_pass_routing_expansion(self):
        import re
        ci=yaml.safe_load((D/'.gitlab-ci.yml').read_text())
        build=yaml.safe_load((D/'.gitlab/build.yml').read_text())['.build test config']
        self.assertNotIn('PRPLOS_BUILDER_TAG',ci['variables'])
        for rule in ci['workflow']['rules'][:2]:
            values={**ci['variables'],**rule['variables'],
                    'CI_MERGE_REQUEST_IID':'3160','CI_COMMIT_REF_SLUG':'campaign',
                    'CI_JOB_NAME_SLUG':'build-test-x86'}
            def expand(value):
                return re.sub(r'\$([A-Z_]+)',lambda m:values.get(m[1],''),value)
            self.assertEqual(expand(build['tags'][0]),'prplos-builder-persistent')
            self.assertRegex(expand(build['image']),r'^registry\.gitlab\.com/[^$]+@sha256:[a-f0-9]{64}$')
            self.assertEqual(expand(build['resource_group']),
                             'build-3160-campaign-build-test-x86')
        values['CI_MERGE_REQUEST_IID']=''
        self.assertEqual(expand(build['resource_group']),'build--campaign-build-test-x86')

    def test_stale_slot_fails_closed(self):
        (self.slot/'.owner').write_text('old')
        r=self.build();self.assertNotEqual(r.returncode,0);self.assertEqual((self.slot/'.owner').read_text(),'old')

    def test_yaml_preserves_existing_jobs_and_steps(self):
        old=yaml.safe_load((SRC/'.gitlab-ci.yml').read_text());new=yaml.safe_load((D/'.gitlab-ci.yml').read_text())
        for name,job in old.items():
            if name not in ['variables']:
                actual=json.loads(json.dumps(new[name]))
                if name.startswith('build test ') and 'rules' in actual:
                    for rule in actual['rules']:rule.pop('variables',None)
                self.assertEqual(actual,job)
        old=yaml.safe_load((SRC/'.gitlab/build.yml').read_text())['.build test config']
        new=yaml.safe_load((D/'.gitlab/build.yml').read_text())['.build test config']
        self.assertEqual(new['script'][1:],old['script'])
        for key in ['before_script','after_script','artifacts']:self.assertEqual(new[key],old[key])
        self.assertEqual([r for r in new['rules'] if 'variables' not in r],old['rules'])

    def test_multiline_config_and_metrics(self):
        r=self.build(CI_BUILD_CONFIG='+FIRST\n', CI_BUILD_CONFIG_EXTRA='+LAST')
        self.assertEqual(r.returncode,0,r.stderr)
        config=(self.tree()/'.config').read_text()
        self.assertIn('CONFIG_LAST=y',config)
        self.assertIn('CONFIG_FIRST=y',config)
        self.assertIn(str(self.persist/'dl-slots/0'),config)
        metrics=json.loads((self.project/'logs/build-metrics.json').read_text())
        fields={'schema_version','job_id','scenario','target','profile','status','wall_s','job_elapsed_s',
                'compile_world_s','ccache_enabled','ccache_hits','ccache_misses','ccache_uncacheable',
                'tree_bytes','sha','parent_sha','feed_revisions','config_sha256','builder_digest',
                'tree_key','tree_reused','clean_build','runner','make_jobs','repetition','timers_s','clean_actions'}
        self.assertEqual(set(metrics),fields)
        self.assertEqual(metrics['make_jobs'],12)
        for command in (self.t/'make.log').read_text().splitlines():
            if '-j ' in command:self.assertIn('-j 12',command)
        self.assertEqual(metrics['ccache_hits'],12)
        self.assertIsNone(metrics['tree_bytes']);self.assertIsNone(metrics['repetition'])
        self.assertFalse(metrics['tree_reused'])
        r=self.build(CI_BUILD_CONFIG='+FIRST\n', CI_BUILD_CONFIG_EXTRA='+LAST');self.assertEqual(r.returncode,0,r.stderr)
        self.assertTrue(json.loads((self.project/'logs/build-metrics.json').read_text())['tree_reused'])

    def test_download_copy_and_append_only(self):
        shared=self.persist/'dl';shared.mkdir(exist_ok=True);(shared/'source.tar').write_text('original')
        self.assertEqual(self.build().returncode,0)
        slot=self.persist/'dl-slots/0'
        self.assertNotEqual((slot/'source.tar').stat().st_ino,(shared/'source.tar').stat().st_ino)
        (slot/'source.tar').write_text('slot-change');(slot/'new.tar').write_text('new')
        (slot/'unfinished.dl').write_text('partial')
        self.assertEqual(self.build().returncode,0)
        self.assertEqual((shared/'source.tar').read_text(),'original')
        self.assertEqual((slot/'source.tar').read_text(),'slot-change')
        self.assertEqual((shared/'new.tar').read_text(),'new')
        self.assertFalse((shared/'unfinished.dl').exists())
        (slot/'failure.tar').touch()
        self.assertEqual(self.build(MOCK_FAIL='1').returncode,7)
        self.assertFalse((shared/'failure.tar').exists())

    def test_term_detaches_and_conflict_keeps_owner(self):
        wrapper=str(self.project/'.gitlab/scripts/with-tree')
        r=run(['bash',wrapper,'bash','-c','kill -TERM "$PPID"'],env=self.env)
        self.assertEqual(r.returncode,143,r.stderr);self.assertFalse((self.slot/'.owner').exists())
        self.assertTrue(self.tree().is_dir())
        command='mkdir -p "'+str(self.persist)+'/trees/$BUILD_TREE_KEY"'
        r=run(['bash',wrapper,'bash','-c',command],env=self.env)
        self.assertNotEqual(r.returncode,0);self.assertTrue((self.slot/'.owner').exists())
        self.assertIn('reconciliation',r.stderr)

    def test_malformed_state_and_generator_guard(self):
        self.assertEqual(self.build().returncode,0)
        tree=self.tree();(tree/'bin/sentinel').touch()
        (tree/'.persistent-success.json').write_text('{"sha":"x","feed_revisions":null}')
        self.assertEqual(self.build().returncode,0);self.assertFalse((tree/'bin/sentinel').exists())
        (tree/'bin/sentinel').touch();(tree/'.genconfig-state').mkdir(exist_ok=True)
        (tree/'.genconfig-state/incremental-plan.failed').touch()
        self.assertEqual(self.build().returncode,0);self.assertFalse((tree/'bin/sentinel').exists())

    def test_failure_sections_diagnostics_and_optional_ccache(self):
        (self.bin/'ccache').write_text('#!/bin/sh\nexit 127\n')
        r=self.build(MOCK_FAIL='1');self.assertEqual(r.returncode,7,r.stderr)
        log=(self.project/'logs/build.log').read_text()
        self.assertIn('section_end:compile-world',log)
        commands=(self.t/'make.log').read_text()
        self.assertIn('package/install V=s',commands)
        self.assertIn('target/install -j',commands)
        self.assertTrue((self.project/'.build_failed').exists())
        self.assertFalse((self.project/'packages-hash-issues.patch').exists())
        self.assertFalse((self.project/'feed-packages-hash-issues.patch').exists())
        self.assertIn('tools-tar-compile',log);self.assertIn('download',log)

    def test_artifact_copy_failure_retains_failure_marker(self):
        cp=self.bin/'cp'
        cp.write_text('#!/bin/sh\ncase "$*" in "-a bin "*) exit 23;; esac\nexec /bin/cp "$@"\n');cp.chmod(0o755)
        r=self.build();self.assertNotEqual(r.returncode,0)
        self.assertTrue((self.tree()/'.build_failed').exists())
        self.assertTrue((self.tree()/'.incomplete').exists())

    def test_tool_failure_and_hash_patch(self):
        r=self.build(MOCK_TOOLS='1');self.assertEqual(r.returncode,9,r.stderr)
        log=(self.project/'logs/build.log').read_text()
        self.assertIn('tools fixture failure',log)
        self.assertIn('section_end:tools-tar-compile',log)
        r=self.build(MOCK_HASH='1');self.assertNotEqual(r.returncode,0)
        self.assertIn('+checksum repair',(self.project/'packages-hash-issues.patch').read_text())
        tree=self.tree();(tree/'bin').mkdir(exist_ok=True);(tree/'bin/sentinel').touch()
        self.assertEqual(self.build().returncode,0);self.assertFalse((tree/'bin/sentinel').exists())

    def test_empty_plan_and_exact_profile(self):
        self.assertEqual(self.build().returncode,0)
        tree=self.tree();(tree/'bin/sentinel').touch()
        helper=self.project/'.gitlab/scripts/persistent-policy.py'
        helper.write_text(helper.read_text().replace("        plan()", "        pass"))
        r=self.build(CI_BUILD_PROFILE='qca_ipq95xx extender_minimal security')
        self.assertEqual(r.returncode,0,r.stderr);self.assertFalse((tree/'bin/sentinel').exists())
        metrics=json.loads((self.project/'logs/build-metrics.json').read_text())
        self.assertNotEqual(metrics['target'],'Freedom')

    def test_nested_feed_manifest_and_independent_diff(self):
        self.assertEqual(self.build().returncode,0)
        tree=self.tree();feed=tree/'feeds/example';leaf=feed/'net/plugins/foo';leaf.mkdir(parents=True)
        (leaf/'Makefile').write_text('include $(TOPDIR)/rules.mk\n$(eval $(call BuildPackage,foo))')
        (leaf/'src.c').write_text('old')
        run(['git','init','-q',str(feed)],check=True)
        def commit_feed():
            run(['git','-C',str(feed),'add','.'],check=True)
            run(['git','-C',str(feed),'-c','user.name=Fixture','-c','user.email=fixture@example.invalid','-c','commit.gpgsign=false','commit','-qm','fixture'],check=True)
            return run(['git','-C',str(feed),'rev-parse','HEAD'],check=True).stdout.strip()
        link=tree/'package/feeds/example/foo';link.parent.mkdir(parents=True)
        link.symlink_to('../../../feeds/example/net/plugins/foo')
        with (tree/'.git/info/exclude').open('a') as exclude:
            exclude.write('/package/feeds/\n')
        old=commit_feed();(leaf/'src.c').write_text('new');new=commit_feed()
        state=json.loads((tree/'.persistent-success.json').read_text());state['feed_revisions']={'example':old}
        (tree/'.persistent-success.json').write_text(json.dumps(state))
        sha=self.env['CI_COMMIT_SHA']
        manifest=dict(schema=1,phase='setup-complete',requires_full_rebuild=False,
                      root=dict(old_sha=sha,new_sha=sha,changed_paths=[],dirty_paths=sorted(record[3:] for record in run(
                          ['git','status','--porcelain','-uall','-z'],cwd=tree,check=True).stdout.split('\0') if record)),
                      feeds=[dict(name='example',old=dict(sha=old,method='src-git',source='fixture'),
                                  new=dict(sha=new,method='src-git',source='fixture'),
                                  changed_paths=['net/plugins/foo/src.c'],requires_full_rebuild=False)])
        def plan():
            (tree/'logs/incremental-plan.json').write_text(json.dumps(manifest))
            return run(['python3',str(D/'.gitlab/scripts/persistent-policy.py'),'plan'],cwd=tree,env=self.env)
        r=plan();self.assertEqual(r.stdout.splitlines(), ['packages', 'package/feeds/example/foo'], r.stderr)
        for target in r.stdout.splitlines()[1:]:
            self.assertTrue((tree/target).is_dir(), target)
        link.unlink()
        r=plan();self.assertEqual(r.stdout.strip(), 'fresh')
        self.assertIn('unselected or ambiguous feed recipe', r.stderr)
        link.symlink_to('../../../feeds/example/net/plugins/foo')
        alias=link.with_name('alias');alias.symlink_to(link.readlink())
        r=plan();self.assertEqual(r.stdout.strip(), 'fresh')
        self.assertIn('unselected or ambiguous feed recipe', r.stderr)
        alias.unlink()
        manifest['feeds'][0]['changed_paths']=[]
        r=plan();self.assertEqual(r.stdout.strip(),'fresh');self.assertIn('diff mismatch',r.stderr)
        manifest['feeds'][0]['old']=None
        self.assertEqual(plan().stdout.strip(),'fresh')

    def test_phase_one_env_gate_and_custom_jobs(self):
        self.assertEqual(self.build().returncode,0)
        tree=self.tree();(tree/'bin/sentinel').touch()
        generator=self.project/'scripts/gen_config.py'
        generator.write_text(generator.read_text().replace('# --incremental','# --incremental\nimport sys\nif "--incremental" in sys.argv: raise SystemExit(91)'))
        self.commit()
        r=self.build(BUILD_INCREMENTAL_GENERATOR='0',BUILD_JOBS='5')
        self.assertEqual(r.returncode,0,r.stderr);self.assertTrue((tree/'bin/sentinel').exists())
        self.assertIn('-j 5 tools/tar/compile',(self.t/'make.log').read_text())
    def test_cancel_keeps_tree_and_reports_interrupted(self):
        self.assertEqual(self.build().returncode,0)
        tree=self.tree();(tree/'bin/sentinel').touch()
        r=run(['bash',str(self.project/'.gitlab/scripts/with-tree'),'bash','-c','kill -TERM "$PPID"'],env=self.env)
        self.assertEqual(r.returncode,143,r.stderr)
        self.assertIn(['DETACH','0','143','1'],self.broker.requests)
        self.assertEqual(self.build().returncode,0);self.assertTrue((tree/'bin/sentinel').exists())
    def test_attach_postreply_error_detaches(self):
        self.broker.bad_attach=True
        r=self.build();self.assertNotEqual(r.returncode,0)
        self.assertTrue(any(r[0]=='DETACH' for r in self.broker.requests))
        self.assertFalse((self.slot/'.owner').exists())
    def test_publish_error_still_detaches_and_errors_identify_unknown_location(self):
        self.broker.failure='PUBLISH-DL'
        r=self.build();self.assertNotEqual(r.returncode,0)
        self.assertIn(['DETACH','0','1','0'],self.broker.requests)
        self.broker.failure='DETACH'
        r=self.build();self.assertNotEqual(r.returncode,0)
        self.assertIn('tree location is unknown',r.stderr)
    def test_skip_integrity_label_disables_check_and_fixup(self):
        r=self.build(CI_MERGE_REQUEST_LABELS='skip_integrity_check')
        self.assertEqual(r.returncode,0,r.stderr)
        commands=(self.t/'make.log').read_text()
        self.assertIn('-j 12 download\n',commands);self.assertNotIn('FIXUP=',commands)
        self.assertNotIn('download check',commands)
    def test_baseline_snapshot_matches_pinned_upstream(self):
        source=os.environ.get('PRPLOS_SRC')
        if not source:self.skipTest('Set PRPLOS_SRC for pinned upstream snapshot validation')
        for name in ['.gitlab-ci.yml','.gitlab/build.yml']:
            original=subprocess.check_output(['git','-C',source,'show','32b4529301e4631e5f1f5ab6dad3c097148e9644:'+name])
            self.assertEqual((SRC/name).read_bytes(),original)
    def test_routing_kill_switch_and_build_only_depth(self):
        ci=yaml.safe_load((D/'.gitlab-ci.yml').read_text())
        for rule in ci['workflow']['rules'][:2]:
            self.assertIn('$PRPLOS_PERSISTENT_ROUTING != "0"',rule['if'])
            self.assertNotIn('GIT_DEPTH',rule['variables'])
        self.assertEqual(ci['variables']['BUILD_PERSISTENT'],'0')
        self.assertEqual(ci['workflow']['rules'][-1]['variables']['BUILD_RUNNER_TAG'],'firmware-builder')
        build=yaml.safe_load((D/'.gitlab/build.yml').read_text())['.build test config']
        for name,job in [('.build test config',build),*ci.items()]:
            if not isinstance(job,dict):continue
            for rule in job.get('rules',[]):
                if 'GIT_DEPTH' in rule.get('variables',{}):
                    self.assertTrue(name=='.build test config' or name.startswith('build test '))
                    self.assertIn('$CI_PIPELINE_SOURCE == "merge_request_event"',rule['if'])
    def test_missing_tree_after_attach_still_detaches(self):
        self.broker.missing_tree=True
        r=self.build();self.assertNotEqual(r.returncode,0)
        self.assertTrue(any(a[0]=='DETACH' for a in self.broker.requests))
        self.assertFalse((self.slot/'.owner').exists())
    def test_feed_integrity_patch_uses_feed_name(self):
        self.assertEqual(self.build().returncode,0)
        feed=self.tree()/'feeds/example';feed.mkdir(parents=True)
        run(['git','init','-q',str(feed)],check=True)
        (feed/'Makefile').write_text('original')
        run(['git','-C',str(feed),'add','.'],check=True)
        run(['git','-C',str(feed),'-c','user.name=Fixture','-c','user.email=fixture@example.invalid','-c','commit.gpgsign=false','commit','-qm','feed'],check=True)
        (feed/'Makefile').write_text('changed')
        # Skip selective planning to exercise the integrity check on the retained feed.
        r=self.build(BUILD_INCREMENTAL_GENERATOR='0')
        self.assertNotEqual(r.returncode,0)
        self.assertTrue((self.project/'example-packages-hash-issues.patch').exists())
        self.assertFalse((self.project/'packages-hash-issues.patch').exists())

    def test_broker_connection_failure_is_diagnostic(self):
        self.broker.path.unlink()
        r=self.build();self.assertNotEqual(r.returncode,0)
        self.assertIn('broker request failed',r.stderr);self.assertNotIn('Traceback',r.stderr)

    def test_public_scripts_do_not_access_pool(self):
        for name in ['with-tree','persistent-build.sh','persistent-policy.py']:
            self.assertNotRegex((D/'.gitlab/scripts'/name).read_text(),r'/persist(?:/|[\s\"\'])')

if __name__=='__main__':unittest.main(verbosity=2)
