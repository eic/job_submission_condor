### Frequently Asked Questions ###


## Common Errors ##

# Example 1

* Scenario 
 
I downloaded a full simulation output file from S3. When I run eicrecon, I see the following error. 
```
[EcalBarrelImagingRecHits] [warning] Failed to load ID decoder for EcalBarrelImagingHits
[WARN] Parameter 'BEMC:ecalbarrelimagingrawhits:timeResolution' with value '0' loses equality with itself after stringificatin
[FATAL] Segfault detected! Printing backtraces and exiting.

Thread model: pthreads
139636488283840: 
       `- JSignalHandler::handle_sigsegv(int, siginfo_t*, void*) (0x7effbbb2e296)
        `- /lib/x86_64-linux-gnu/libc.so.6 (0x7effbb61bf90)
         `- ImagingPixelReco::execute() (0x7effb7887511)
          `- CalorimeterHit_factory_EcalBarrelImagingRecHits::Process(std::shared_ptr<JEvent const> const&) (0x7effb78879c9)
           `- eicrecon::JFactoryPodioT<edm4eic::CalorimeterHit>::Create(std::shared_ptr<JEvent const> const&) (0x7effb7908c7e)
            `- std::vector<edm4eic::CalorimeterHit const*, std::allocator<edm4eic::CalorimeterHit const*> > JEvent::Get<edm4eic::CalorimeterHit>(std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&) const (0x7effb790d28e)
             `- ProtoCluster_factory_EcalBarrelImagingProtoClusters::Process(std::shared_ptr<JEvent const> const&) (0x7effb78677fa)
              `- eicrecon::JFactoryPodioT<edm4eic::ProtoCluster>::Create(std::shared_ptr<JEvent const> const&) (0x7effb79098be)
               `- std::vector<edm4eic::ProtoCluster const*, std::allocator<edm4eic::ProtoCluster const*> > JEvent::Get<edm4eic::ProtoCluster>(std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&) const (0x7effb790c45e)
                `- Cluster_factory_EcalBarrelImagingClusters::Process(std::shared_ptr<JEvent const> const&) (0x7effb7871701)
                 `- eicrecon::JFactoryPodioT<edm4eic::Cluster>::Create(std::shared_ptr<JEvent const> const&) (0x7effb790a4fe)
                  `- JEvent::GetCollectionBase(std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> >) const (0x7effb7ca85f6)
                   `- JEventProcessorPODIO::Process(std::shared_ptr<JEvent const> const&) (0x7effb7165a87)
                    `- JEventProcessor::DoMap(std::shared_ptr<JEvent const> const&) (0x7effbbab47bd)
                     `- JEventProcessorArrow::execute(JArrowMetrics&, unsigned long) (0x7effbba9c6c5)
                      `- JWorker::loop() (0x7effbbaa74d7)
                       `- /usr/lib/x86_64-linux-gnu/libstdc++.so.6 (0x7effbb8b54a3)
                        `- /lib/x86_64-linux-gnu/libc.so.6 (0x7effbb668fd4)
                         `- __clone (0x7effbb6e8820)
```  

* Explanation

Eicrecon is trying to access a collection that doesn't exist for the detector config with which the original simulation was run with.

* Solution

Make sure the correct tagged detector geometry environment was sourced and DETECTOR_CONFIG variable was defined. 

```
source /opt/detector/epic-23.05.2/setup.sh
DETECTOR_CONFIG=epic_brycecanyon eicrecon -Ppodio:output_file=<prefix>.eicrecon.tree.edm4eic.root  -Pjana:warmup_timeout=0 -Pjana:timeout=0 -Pplugins=janadot <prefix>.edm4hep.root
```
