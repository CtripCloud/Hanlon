test_name "Get ready to install Hanlon using Puppet"

step "install hanlon modules"
# Find the package, and ensure we only have one!
require 'pathname'
if (modules = Pathname.glob("#{ENV['WORKSPACE']}/pkg/puppetlabs-hanlon-*.tar.gz")).size == 1
  pkg = modules[0].basename
  puts "we found #{pkg} to install"
else
  puts "we found NOTHING to install!"
  fail_test "unable to proceed, multiple modules found: #{modules.join(", ")}"
end

on hosts('hanlon-server'), "rm -f /tmp/puppetlabs-hanlon-*.tar.gz"
scp_to(hosts('hanlon-server'), "#{ENV['WORKSPACE']}/pkg/#{pkg}", '/tmp')
on hosts('hanlon-server'), "puppet module install --force /tmp/#{pkg}"

module_list  = "puppet module list --color=false 2>&1"
missing_deps = "#{module_list} | sed -ne '/Missing dependency/ s/^.*'\\''\\(.*\\)'\\''.*$/\\1/ p'"
next_missing = "$(#{missing_deps} | head -n1)"
on hosts('hanlon-server'), "module=\"#{next_missing}\"
while test -n \"${module}\"; do
    echo \"installing ${module}\"
    puppet module install --color=false \"${module}\"
    module=\"#{next_missing}\"
done"

if ENV['INSTALL_MODE'] == 'internal-packages' then
  step "configure internal package repositories"
  on hosts('hanlon-server'), puppet_apply("--verbose"), :stdin => %Q'
apt::key { "internal-packages":
  key        => "27D8D6F1",
  key_source => "http://neptune.puppetlabs.lan/dev/hanlon/deb/#{ENV['debbuild'] || 'current'}/pubkey.gpg",
  before     => Apt::Source["internal-packages"]
}

apt::source { "internal-packages":
  location    => "http://neptune.puppetlabs.lan/dev/hanlon/deb/#{ENV['debbuild'] || 'current'}",
  release     => $lsbdistcodename,
  repos       => "main",
  include_src => false
}
'
end


step "install gems to run the test suite"
on hosts('hanlon-server'), puppet_apply("--verbose"), :stdin => %q'
  package { [rake, rspec, mocha, net-ssh]: ensure => installed, provider => gem }
  package { curl: ensure => installed }
'
